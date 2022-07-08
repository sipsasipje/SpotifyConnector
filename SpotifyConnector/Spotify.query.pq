let
   list = #table({"artist"}, {{"queen"},{"beethoven"},{"kate%20bush"},{"the%20beatles"},{"bts"}}),
   GetMeSomeData = (input) => 
      let 
       data = Spotify.Contents("https://api.spotify.com/v1/search?q=" & input & "&type=artist&limit=1")
      in 
       data,
    result = Table.AddColumn(lijst, "Data", each Function.InvokeAfter(()=>GetMeSomeData([artist]),#duration(0,0,0,1)))
in
    result
