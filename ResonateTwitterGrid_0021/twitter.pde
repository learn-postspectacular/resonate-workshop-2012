// if ONLINE is true, this method loads an Atom feed from the Twitter search API or
// loads a locally cached version from the /data folder.
// Once the results are loaded, we also do some basic analysis and map the
// feed entries to grid positions
List<TweetPoint> initTwitter() {
  AtomFeed feed;
  if (!ONLINE) {
    feed=AtomFeed.newFromStream(openStream("search.atom"));
  } 
  else {
    feed=AtomFeed.         
      newFromURL("http://search.twitter.com/search.atom?q="+QUERY);
  }
  // a hashmap stores key=>value pairs and allows us to retrieve values by key/name
  // here we use it to extract unique authors and count how many tweets each has associated
  HashMap<String, Integer> uniqueAuthors=new HashMap<String, Integer>();
  // identify unique authors in search results
  for (AtomEntry e : feed.entries) {
    String name=e.author.name;
    // check if author is already known...
    if (uniqueAuthors.containsKey(name)) {
      int freq=uniqueAuthors.get(name);
      freq++;
      uniqueAuthors.put(name, freq);
      println(name+"="+freq);
    } 
    else {
      println("new author: "+name);
      uniqueAuthors.put(name, 1);
    }
  }
  // next we sort all feed entries by time
  // in the case of twitter this is not strictly essential since they're already sorted
  // but I wanted to explain the overall approach of sorting a collection based on some
  // specific (and possibly deeply nested) criteria/property...
  Collections.sort(feed.entries, new Comparator<AtomEntry>() {

    // the contract of the compare function is to return these values:
    // negative int, if a < b
    // zero, if a==b
    // positive int, if a > b
    public int compare(AtomEntry a, AtomEntry b) {
      long atime=a.timePublished.toGregorianCalendar().getTimeInMillis();
      long btime=b.timePublished.toGregorianCalendar().getTimeInMillis();
      return (int)(atime-btime);
    }
  }
  );
  // figure out time of oldest and newest tweet
  long tmin=feed.entries.get(0)
    .timePublished
      .toGregorianCalendar()
      .getTimeInMillis();
  long tmax=feed.entries.get(feed.entries.size()-1)
    .timePublished
      .toGregorianCalendar()
      .getTimeInMillis();
  // put all author names into a new list
  // this is required since we want to map authors to the X axis of the grid
  // however, this is not possible with a hashmap since its keys (the author names)
  // are stored in an unordered set. Translating the set into a list we can use
  // the list position as metric for mapping to X coordinates
  // The actual tweets themselves are already stored in a list and since it is sorted
  // by time, we already have a similar direct mapping for time -> grid Y axis
  List<String> names=new ArrayList<String>(uniqueAuthors.keySet());
  // map entries on grid and populate list of TweetPoints
  tweets=new ArrayList<TweetPoint>();
  for (AtomEntry e : feed.entries) {
    // get list index for author
    int a=names.indexOf(e.author.name);
    // get timestamp of tweet as Unix Epoch (milliseconds since 1/1/1970)
    long t=e.timePublished.toGregorianCalendar().getTimeInMillis();
    // compute XY grid coordinates for tweet
    float x=map(a, 0, uniqueAuthors.size()-1, -RESX/2, RESX/2-1);
    float y=map(t, tmin, tmax, RESY/2-1, -RESY/2);
    // add point to list
    TweetPoint tp=new TweetPoint(new Vec2D(x, y), e);
    tweets.add(tp);
  }
  return tweets;
}

