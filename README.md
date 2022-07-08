# SpotifyConnector
A Power BI Desktop custom data connector for the Spotify API.

Find [the most depressing track](https://developer.spotify.com/discover/#audio-features-analysis) in your playlists. Discover which cheesy 90's artist has the biggest ego and reissued their song in 20 different versions. This connector allows you to get data from Spotify directly into Power BI tables. With some Power Query M Code it can handle batch imports for large sets. The connector accepts [any endpoint URI](https://developer.spotify.com/documentation/web-api/reference/) of the Spotify Web API.

## Prerequisites
* Login to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard/) using your Spotify account (free or premium).
* Click the *Create an app* button and give your app a name and description. Click the *Create* button.
* Save your client ID and client secret somewhere safe.
 
 <img src="/images/credentials.png" width=40%>

* Click the *Edit settings* button.
* Add `https://oauth.powerbi.com/views/oauthredirect.html` to *Redirect URIs*. Click the *Save* button at the bottom.

<img src="/images/spotify-settings.png" width=40%>

## Quickstart

If you're not interested in the inner workings of the connector and just want to start making a flashy dashboard, use this quickstart option.

* Rename /QuickStart/SpotifyConnector.mez to SpotifyConnector.zip
* Unzip this file.
* Add your client ID and client secret to client_id.txt and client_secret.txt respectively.
* Zip the files again and rename the resulting file to .mez
* Place this .mez file in this exact folder `/Users/[Your username]/Documents/Power BI Desktop/Custom Connectors`

## Basic usage

* Open Power BI.
* Click *Get data* > *More...*
* Search for and select *Spotify (Beta)* and click *Connect*
* The first time you do this, you must login to Spotify. A popup will open.
* Input any endpoint URI with parameters in the url field and click *OK*

<img src="/images/getdata.png" width=60%>

Depicted here is the endpoint `/search` which searches for the string 'Jimi Hendrix' which we want to find in 'artist'. In many cases the search endpoint will be your starting point, since other endpoints such as `/artists` and `/albums` require a unique ID. You can find the artist ID for Jimi Hendrix in the data returned by the search in this example. The data is returned in JSON format, so you'll have to navigate through some levels once Power BI has received a response from Spotify.

Find all available endpoint addresses [here](https://developer.spotify.com/console), where you can also try them out directly in your browser.

## Into the deep

In order to edit and compile the connector files, you'll need Visual Studio.

* Download and install [Visual Studio](https://visualstudio.microsoft.com/vs/older-downloads/). Currently Visual Studio 2019 is the most recent version that supports the Power Query SDK extension.
* Start Visual Studio and choose *Continue without code*

<img src="/images/firstrun.png" width=30%>

* Go to *Extensions* > *Manage extensions*.
* Search for and install `Power Query SDK`

<img src="/images/extensionpopup.png" width=60%>

* Restart Visual Studio
* Put the files from the folder [SpotifyConnector](/SpotifyConnector) in a folder of your choice.

### Project files

| File              | Description                                                   |
| ----------------- | ------------------------------------------------------------- |
| Spotify.mproj     | The Visual Studio project                                     |
| Spotify.pq        | The connector definition                                      |
| Spotify.query.pq  | Power Query M Code for testing the connector in Visual Studio |
| \*.png            | Icons of various resolutions for use in the Power BI GUI      |
| client_id.txt     | The connector reads the client ID from this file              |
| client_secret.txt | The connector reads the client Secret from this file          |
| resources.resx    | Definitions such as button titles for the Power BI GUI        |

### Spotify.pq

This file contains the actual connector logic.

In order to access the API:
<ol>
<li>Spotify needs to authorize you - with your username and password.</li>
<li>It needs to identify the application you created in the developer dashboard - using the client ID.</li>
<li>Spotify assumes the authentication requests come from a web application and returns its approval or denial to a redirect URI. That's why you needed to white-list powerbi.com as a prerequisite.</li>
</ol>

To actually get data:

<ol start=4>
<li>You need an access token.</li>
<li>A token is valid for a limited time (3600 seconds). You also need a special refresh token that you can exchange for a new access token.</li>
<li>You get these tokens using your client ID and secret.</li>
</ol>

The connector logic negotiates with Spotify and handles all these details. This includes refreshing your token when it is nearing its expiry.

<figure>
  <img src="/images/diagram.png" width="40%">
  <figcaption><i>Communications between the Power BI custom connector and Spotify API</i></figcaption>
</figure>

### The inner workings

For a further explanation of the mechanics of the connector, [I refer to the code](/SpotifyConnector/Spotify.pq), which contains a myriad of comments.

### Modify and compile the connector

#### Why modify?

* The code is a basis for creating connectors for any OAUTH2 API.
* You may want data related to a user, in which case you need to define scopes.
* There's settings that affect how the connector is displayed in the Power BI UI.
* You just want to change random things and watch Power BI crash and burn.

#### To modify

* Open `Spotify.mproj` in Visual Studio
* Edit anything in `Spotify.pq`
* Don't forget to add your client ID and secret to the corresponding .txt files
* You can run Power Query M Code to test the connector: open `Spotify.query.pq` and press *Start* in the toolbar

#### To compile

* Choose *Build* > *Build Spotify* from the main menu to compile the connector
* Go to `[Your project folder]/bin/Debug` and copy `Spotify.mez`
* Place this .mez file in this exact folder `/Users/[Your username]/Documents/Power BI Desktop/Custom Connectors`

\<nerdfact\> Technically this build command does not compile anything. The necessary files are merely packaged into the .mez file. If you rename .mez to .zip you can actually unzip it to retrieve the original project files. \<\/nerdfact\>

### A word on scopes

If you want to request data related to your Spotify user, such as playlists or listening history, you need to define [the appropriate scopes](https://developer.spotify.com/documentation/general/guides/authorization/scopes/). You can add the desired scope names to the connector definition.

For instance:

`scopes = {"playlist-read-private", "playlist-read-collaborative"}`

Allows you to use the endpoint `https://api.spotify.com/v1/users/{user_id}/playlists` to get all your playlists. Of course you can only get scoped data for the user currently logged in.

## Usage within M Code

To use the connector from Power Query call *Spotify.Contents*. The argument you supply this function should always be an endpoint URI with parameters.

For example:

```
let
  data = Spotify.Contents("https://api.spotify.com/v1/artists/" & someartistID & "/albums?limit=1")
in
  data
```

### Full tables with a little throttle

If you want to get larger data sets, you will have to call the Spotify.Contents function recursively. Spotify limits the number of calls you can make to its API within a certain amount of time. To throttle the number of requests, wrap your connector calls in a function and use M Code's InvokeAfter.

For instance:

`each Function.InvokeAfter(()=>GetMeSomeData([artist]),#duration(0,0,0,0.3))`

If you call Spotify.Contents from GetMeSomeData, this will limit the API requests to one per 300 milliseconds, which should be enough to prevent Spotify from returning *429 too many requests* errors.

## Head start projects

Please check out [@JWmaker](https://github.com/JWmaker)'s tutorials for a great introduction for importing data to Power BI from sources like Spotify:

[JW's tutorial on Power BI and Spotify](https://www.youtube.com/watch?v=5PPKto7z_ak)  
[JW's tutorial on Power BI and IMDB](https://www.youtube.com/watch?v=CYdEjVdqHp0)
