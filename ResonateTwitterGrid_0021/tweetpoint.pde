// This class encapsulates all required information for visualizing tweets
// in conjunction with the underlying physics grid
class TweetPoint {

  // position of the tweet in grid coordinates
  Vec2D gridPos;
  // position of tweet on screen (after 3D->2D projection)
  Vec2D screenPos;
  // related grid particle
  VerletParticle3D particle;
  // actual tweet
  AtomEntry tweet;

  TweetPoint(Vec2D p, AtomEntry t) {
    gridPos=p;
    tweet=t;
    // keep a reference to underlying related grid particle
    particle=physics.particles.get(index((int)p.x+RESX/2, (int)p.y+RESY/2));
  }

  void drawLabel(ToxiclibsSupport gfx) {
    fill(LABEL_BG_COLOR.toARGB());
    List<String> lines=wordWrapText(tweet.title, 200);
    int num=lines.size();
    int h=TEXT_LEADING * num + 2 * TEXT_LEADING;
    float x=min(screenPos.x, width - 230);
    float y=min(screenPos.y, height - h - 2*TEXT_LEADING);
    rect(x - 10, y - TEXT_LEADING, 220, h);
    fill(LABEL_TXT_COLOR.toARGB());
    for (int i=0; i<num; i++) {
      text(lines.get(i), x, y + i * TEXT_LEADING, 200, 1000);
    }
  }
}

