section Spotify; // Required: groups all expressions in this document under the name "Spotify"

// Gets client ID and secret from external txt files. Paste your Spotify client ID and secret in these files.
client_id = Text.FromBinary(Extension.Contents("client_id.txt"));
client_secret = Text.FromBinary(Extension.Contents("client_secret.txt"));

authorize_uri = "https://accounts.spotify.com/authorize"; // Log in to Spotify here.
token_uri = "https://accounts.spotify.com/api/token"; // Get a new a token here.
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html"; // Callback that Spotify refers to after the authorisation process.
logout_uri = "https://login.microsoftonline.com/logout.srf"; // Generic service that responds to a logout action.

// Settings for the Power BI UI
windowWidth = 720;
windowHeight = 1024;

scopes = {""}; // If you want to request data related to a user, like playlists, you need to define the scopes you want to access here. See https://developer.spotify.com/documentation/general/guides/authorization/scopes/

// The main function we will be calling when getting data from Spotify.
[DataSource.Kind="Spotify", Publish="Spotify.Publish"]
shared Spotify.Contents = (optional url as text) => // Accepts an end point address with parameters.
    let
        source = Json.Document(Web.Contents(url)) // Returns data as JSON.
    in
        source; 


// Settings for the connector itself.
Spotify = [
    TestConnection = (dataSourcePath) => { "Spotify.Contents", dataSourcePath }, // How the connector can test if the connection is live.
    Authentication = [
       OAuth = [
           // Which functions handle diffent parts of the authentication process. Functions are defined below.
            StartLogin=StartLogin,
            FinishLogin=FinishLogin,
            Refresh=Refresh,
            Logout=Logout
       ]
    ],
    Label = Extension.LoadString("DataSourceLabel") // Name of the connector.
];

// More settings that show up in the Power BI UI
Spotify.Publish = [
    Beta = true, // Displays a warning that this is not a final version.
    Category = "API",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Spotify.Icons, // See the icon definitions below.
    SourceTypeImage = Spotify.Icons
];

// Request access to Spotify using your credentials.
StartLogin = (resourceUrl, state, display) =>
    let
        authorizeUrl = authorize_uri & "?" & Uri.BuildQueryString([
            response_type = "code",
            client_id = client_id,  
            redirect_uri = redirect_uri,
            state = state,
            scope = GetScopeString(scopes)
        ])
    in
        [
            LoginUri = authorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = 720,
            WindowWidth = 1024,
            Context = null
        ];

// Handles callback after authorisation.
FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query], // Get the query string (parameter) part of the callback uri.
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts) // There was an error field in the query string.
                 else
                    TokenMethod("authorization_code", "code", parts[code]) // There was no error. Continue to get a token.
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token", "refresh_token", refresh_token); // What to do when we need a new token.

Logout = (token) => logout_uri; // What to do when logging out.

// Handles getting a new token
TokenMethod = (grantType, tokenField, code) =>
    let
        queryString = [
            grant_type = grantType, // "authorization_code" if we have no existing token, "refresh_token" if we want to exchange the current token for a new one.
            redirect_uri = redirect_uri, // Spotify will refer to the callback again after providing a new token.
            client_id = client_id,
            client_secret = client_secret
        ],
        queryWithCode = Record.AddField(queryString, tokenField, code),

        // Add some extra settings in the request header and call Spotify for a new token.
        tokenResponse = Web.Contents(token_uri, [
            Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
            Headers = [
                #"Content-type" = "application/x-www-form-urlencoded",
                #"Accept" = "application/json"
            ],
            ManualStatusHandling = {400} 
        ]),
        body = Json.Document(tokenResponse), // Hopefully contains our token.
        result = if (Record.HasFields(body, {"error", "error_description"})) then 
                    error Error.Record(body[error], body[error_description], body) // Nope, no token for us this time, something went wrong.
                 else
                    body // We have a new token! Now we can start requesting data.
    in
        result;

// Concatenates provided scopes.
GetScopeString = (scopes as list) as text =>
    let
        asText = Text.Combine(scopes, " ")
    in
        asText;

// Icon definitions. External files in various resolutions.
Spotify.Icons = [
    Icon16 = { Extension.Contents("Spotify16.png"), Extension.Contents("Spotify20.png"), Extension.Contents("Spotify24.png"), Extension.Contents("Spotify32.png") },
    Icon32 = { Extension.Contents("Spotify32.png"), Extension.Contents("Spotify40.png"), Extension.Contents("Spotify48.png"), Extension.Contents("Spotify64.png") }
];
