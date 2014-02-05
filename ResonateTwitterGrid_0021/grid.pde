void initGrid() {
  physics=new VerletPhysics3D();
  for (int y=0; y<RESY; y++) {
    for (int x=0; x<RESX; x++) {
      VerletParticle3D p=new VerletParticle3D(new Vec3D(x-RESX/2, y-RESY/2, 0).scaleSelf(GRID_SCALE));
      physics.addParticle(p);
      if (x>0) {
        // create horizontal connection to previous column
        addConnection(p, x-1, y);
      }
      if (y>0) {
        // create vertical connection to previous row
        addConnection(p, x, y-1);
      }
    }
  }
  // lock grid corner points in space
  physics.particles.get(index(0, 0)).lock();
  physics.particles.get(index(RESX-1, 0)).lock();
  physics.particles.get(index(RESX-1, RESY-1)).lock();
  physics.particles.get(index(0, RESY-1)).lock();
}

// Creates a spring between the given particle and another one at the given grid position.
void addConnection(VerletParticle3D from, int toX, int toY) {
  VerletParticle3D to=physics.particles.get(index(toX, toY));
  physics.addSpring(new VerletSpring3D(from, to, from.distanceTo(to), 0.1));
}

