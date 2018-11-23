# NFL-traffic-light
A old traffic light to blink based on whats happening during NFL games.

the reason its split is because i use the light for other home automation tasks, all documented here...

[Traffic light NFL project](https://drew.beer/blog/blog/nfl-traffic-light)

#### web server

```
./gpio-web.pl daemon
```

### nfl.pl
the top of this script contains the favorite team variable, said your abbreviated team at the top. 

```
./nfl.pl
```

may throw some errors because some vars don't exist for comparing, eventually i'll clean that up


legend is as follows:
* green on during any of the following means your fav team is triggered below
* extra point - 1 x yellow and red
* 2pt conversion - 2 x yellow and red
* field goal - 3 x red
* safety - 2 x red
* touchdown - 6 x yellow and red
