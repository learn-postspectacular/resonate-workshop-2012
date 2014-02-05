/**
 * This project was created during a 1 day workshop at Resonate 2012 festival in Belgrade.
 * This little application creates a 3D visualization of Twitter search results combined
 * with a physics simulation of a grid deformed by tweets floating on its surface.
 *
 * Participants were introduced to basics of vector geometry, working with Atom data feeds,
 * color theory and coordinate system transformations.
 *
 * Please note:
 * 1) This project does not work properly with Processing 2.0 alpha due to some P5
 *    internal incompatibilities with the 1.5.x version...
 * 2) This project requires toxiclibs-0021 or later (has been supplied to all workshop participants).
 *    If you don't have this version of the libraries, please use the ResonateTwitterGrid_0020 version
 *
 * (c) 2012 Karsten Schmidt // LGPL licensed
 */
import toxi.color.*;
import toxi.data.feeds.*;
import toxi.geom.*;
import toxi.math.*;
import toxi.processing.*;
import toxi.physics3d.*;

import processing.opengl.*;

// global configuration settings

// grid resolution
final int RESX=32;
final int RESY=32;

// grid size in 3D world units
final Vec2D GRID_SIZE=new Vec2D(800, 800);
// grid scale to convert from grid coordinates to world space
final Vec3D GRID_SCALE=GRID_SIZE.to3DXY().scale(1.0/(RESX-1), 1.0/(RESY-1), 1);

// frame delay for introducing new tweets to visualization
final int TWEET_DELAY=10;
// Z offset for tweets floating above grid
final int TWEET_OFFSET_Z=10;

// settings for rollover text label
final TColor LABEL_BG_COLOR = TColor.newGrayAlpha(1, 0.8);
final TColor LABEL_TXT_COLOR = TColor.newRGB(0, 0, 1);
final TColor LABEL_ON_COLOR = TColor.newRGB(1, 1, 0);
final TColor LABEL_OFF_COLOR = TColor.newRGB(1, 0, 0);
final int TEXT_LEADING = 14;

// flag, to indicate using online Twitter API or local fixture
boolean ONLINE = false;
// search query string (only used if ONLINE=true)
String QUERY="resonate_io";

// physics simulation
VerletPhysics3D physics;
// graphics helper
ToxiclibsSupport gfx;

// list of tweets
List<TweetPoint> tweets;
// currently selected tweet (in rollover state)
TweetPoint selection;

int tweetId;
int progress;

void setup() {
  size(1024, 768, OPENGL);
  // wire up graphics helper to sketch
  gfx=new ToxiclibsSupport(this);
  initGrid();
  tweets=initTwitter();
  textFont(loadFont("DroidSerif-12.vlw"));
}

void draw() {
  background(0);
  lights();
  // backup default 2D coordinate system
  pushMatrix();
  // switch to 3D coord system with origin at center of screen
  translate(width/2, height/2, 0);
  // rotate around X axis to create slight landscape view
  rotateX(radians(60));
  // manage slow/delayed introduction of new tweets into the visualization
  progress++;
  if (progress==TWEET_DELAY) {
    progress=0;
    if (tweetId<tweets.size()-1) {
      tweetId++;
      tweets.get(tweetId).particle.jitter(100);
    }
  }
  // update physics simulation
  physics.update();
  // compute 2D screen positions of tweets
  computeTweetPositions();
  // draw spring connections
  stroke(255, 100);
  for (VerletSpring3D s : physics.springs) {
    gfx.line(s.a, s.b);
  }
  // draw grid points
  noStroke();
  for (VerletParticle3D p : physics.particles) {
    // map Z position to hue on color wheel
    gfx.fill(TColor.newHSV(map(p.z, -50, 50, 0, 1), 1, 1));
    // render point as axis-aligned bounding box
    gfx.box(new AABB(p, 1.5));
  }
  // draw tweets
  for (int i=0; i<=tweetId; i++) {
    TweetPoint tp=tweets.get(i);
    // add Z offset to make tweet float above grid
    Vec3D pos=tp.particle.add(0, 0, TWEET_OFFSET_Z);
    // draw as sphere
    // pick correct color based on tweet's rollover state
    gfx.fill(selection==tp ? LABEL_ON_COLOR : LABEL_OFF_COLOR);
    gfx.sphere(new Sphere(pos, 10), 6);
  }
  // restore default 2D coordinate system
  popMatrix();
  // temporarily turn off depth testing to ensure 2D elements are always
  // drawn on top (as overlay) of the 3D scene
  hint(DISABLE_DEPTH_TEST);
  // draw all tweet labels in 2D
  for (int i=0; i<=tweetId; i++) {
    TweetPoint tp=tweets.get(i);
    // pick correct color based on tweet's rollover state
    gfx.fill(selection==tp ? LABEL_ON_COLOR : LABEL_OFF_COLOR);
    text(tp.tweet.author.name, tp.screenPos.x, tp.screenPos.y-20);
  }
  // show tweet content for selected tweet
  if (selection!=null) {
    selection.drawLabel(gfx);
  }
  hint(ENABLE_DEPTH_TEST);
}

// reload tweets upon key press
void keyPressed() {
  if (key=='r') {
    tweets=initTwitter();
    tweetId=0;
    progress=0;
  }
}

// 2D->1D transformation of grid positions. Used for 1D list access
// based on 2D coordinates.
int index(int x, int y) {
  return y * RESX + x;
}

// Convert 3D->2D coordinates of all visible tweets. 
// Must be called from draw() function because we require an
// active 3D coordinate system.
void computeTweetPositions() {
  for (int i=0; i<=tweetId; i++) {
    TweetPoint tp=tweets.get(i);
    Vec3D pos=tp.particle.add(0, 0, TWEET_OFFSET_Z);
    // screenX() & screenY() functions compute the 3D->2D projection
    // of a 3D point in the current coordinate system
    float sx=screenX(pos.x, pos.y, pos.z);
    float sy=screenY(pos.x, pos.y, pos.z);
    // store it for future reference
    tp.screenPos=new Vec2D(sx, sy);
  }
}

// Checks all TweetPoints to figure out mouse rollover state.
// Our tweets are visualized as dots, so we simply need to
// check if mouse position is within a fixed radius.
// If a matching tweet is found it's stored in the
// "selected" variable for future reference...
void mouseMoved() {
  selection=null;
  Vec2D mpos=new Vec2D(mouseX, mouseY);
  for (int i=0; i<=tweetId; i++) {
    TweetPoint tp=tweets.get(i);
    if (tp.screenPos.distanceTo(mpos)<20) {
      selection=tp;
    }
  }
}

// Utility function to wordwrap a String to the given column width.
// Returns a list of new Strings, one per line.
List<String> wordWrapText(String txt, int colWidth) {
  List<String> lines=new ArrayList<String>();
  // split text into words (and remove any existing trailing spaces and line breaks)
  String[] words=split(txt.trim().replaceAll("\n", ""), ' ');
  if (words.length>0) {
    String l=words[0];
    // find maximum line lengths
    for (int i=1; i<words.length; i++) {
      // add next word to current line
      String nl=l+" "+words[i];
      // check if we still fit into column width
      if (textWidth(nl)<=colWidth) {
        l=nl;
      }
      else {
        lines.add(l);
        l=words[i];
      }
    }
    // add last remaining line (if not empty)
    if (l.length()>0) {
      lines.add(l);
    }
  }
  return lines;
}

