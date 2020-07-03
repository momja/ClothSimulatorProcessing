public class ClothMesh {
  public float ks = 2000;
  public float kd = 2000;
  public float restLength = 0.1;
  public float vertexMass = 2;
  public Vec3 gravity = new Vec3(0,-10,0);
  public boolean debugMode = false;

  private int width;
  private int height;
  private Vec3[][] prevPositions;
  public Vec3[][] positions;
  private Vec3[][] velocities;
  private Vec3[][] accelerations;
  private Vec3[][] nodesOnSurfaceNormals;
  private int stepCount = 40;

  // Constructor
  public ClothMesh(int width, int height) {
    this.width = width;
    this.height = height;
    this.restLength = restLength;
    this.vertexMass = vertexMass;
    this.gravity = gravity;
    prevPositions = new Vec3[height][width];
    positions = new Vec3[height][width];
    velocities = new Vec3[height][width];
    accelerations = new Vec3[height][width];
    nodesOnSurfaceNormals = new Vec3[height][width];
    
    // Initialize the vertices so that the cloth is flat.
    for (int i = 0; i < height; i++) {
      for (int j = 0; j < width; j++) {
        positions[i][j] = new Vec3(i * restLength - restLength*height/2, 0, j * restLength - restLength*width/2);
        prevPositions[i][j] = new Vec3(positions[i][j]);
        velocities[i][j] = new Vec3(0, 0, 0);
        accelerations[i][j] = new Vec3(0, 0, 0);
        nodesOnSurfaceNormals[i][j] = null;
      }
    }
  }

  public void draw() {
    // Debug drawing for cloth.
    pushStyle();
    stroke(255,0,0);
    for (int i = 0; i < height - 1; i++) {
      for (int j = 0; j < width - 1; j++) {
        Vec3 topLeft = cloth.positions[i][j];
        Vec3 topRight = cloth.positions[i][j+1];
        Vec3 bottomLeft = cloth.positions[i+1][j];
        Vec3 bottomRight = cloth.positions[i+1][j+1];
        line(topLeft.x, topLeft.y, topLeft.z, topRight.x, topRight.y, topRight.z);
        line(topRight.x, topRight.y, topRight.z, bottomRight.x, bottomRight.y, bottomRight.z);
        line(bottomRight.x, bottomRight.y, bottomRight.z, bottomLeft.x, bottomLeft.y, bottomLeft.z);
        line(bottomLeft.x, bottomLeft.y, bottomLeft.z, topLeft.x, topLeft.y, topLeft.z);
      }
    }
    popStyle();
    if (debugMode) {
        debugDraw();
    }
  }

  public void debugDraw() {
    pushStyle();
    for (int i = 0; i < clothHeight; i++) {
        for (int j = 0; j < clothWidth; j++) {
            strokeWeight(1);
            stroke(0, 255, 0);
            Vec3 velDir = positions[i][j].plus(velocities[i][j].times(0.3));
            line(positions[i][j].x,   positions[i][j].y,   positions[i][j].z,
                    velDir.x, velDir.y, velDir.z);
            strokeWeight(5);
            stroke(0, 0, 255);
            point(positions[i][j].x, positions[i][j].y, positions[i][j].z);
        }
    }
    popStyle();
  }

  public void updateHookes() {
      // Vertical
      for (int i = 0; i < height - 1; i++) {
      for (int j = 0; j < width; j++) {
        // Hooke's Law
        Vec3 springVector = positions[i+1][j].minus(positions[i][j]);
        float springLength = springVector.length();
        springVector.normalize();
        float springForce = -ks * (springLength - restLength);

        // Damping
        float v1 = dot(springVector, velocities[i][j]);
        float v2 = dot(springVector, velocities[i+1][j]);
        float dampingForce = -kd * (v1 - v2);

        Vec3 totalForce = springVector.times(springForce + dampingForce);
        accelerations[i][j].subtract(totalForce.times(1f/vertexMass));
        accelerations[i+1][j] = totalForce.times(1f/vertexMass).plus(gravity);
        
        assert !Double.isNaN(accelerations[i][j].x + accelerations[i][j].y + accelerations[i][j].z) : "Hookes Law Failure";
      }
      }

    //   // Horizontal
    //   for (int i = 0; i < height; i++) {
    //   for (int j = 0; j < width - 1; j++) {
    //     // Hooke's Law
    //     Vec3 springVector = positions[i][j+1].minus(positions[i][j]);
    //     float springLength = springVector.length();
    //     springVector.normalize();
    //     float springForce = -ks * (springLength - restLength);

    //     // Damping
    //     float v1 = dot(springVector, velocities[i][j]);
    //     float v2 = dot(springVector, velocities[i][j+1]);
    //     float dampingForce = -kd * (v1 - v2);

    //     Vec3 totalForce = springVector.times(springForce + dampingForce);
    //     accelerations[i][j].subtract(totalForce.times(0.5/vertexMass));
    //     accelerations[i][j+1].add(totalForce.times(0.5/vertexMass));

    //     assert !Double.isNaN(accelerations[i][j].x + accelerations[i][j].y + accelerations[i][j].z) : "Hookes Law Failure";
    //   }
    //   }
  }
  
  
  // This updates the cloth using simple Eulerian integration.
  // Note: This requires an extremely small dt (<= 0.001).
  public void updateEulerian(float dt) {
    dt = dt/stepCount;
    for (int w = 0; w < stepCount; w++) {        
        updateHookes();
        for (int i = 1; i < height; i++) {
        for (int j = 0; j < width; j++) {
            velocities[i][j].add(accelerations[i][j].times(dt));
        }
        }
        
        // Update the positions.
        for (int i = 1; i < height; i++) {
        for (int j = 0; j < width; j++) {
            positions[i][j].add(velocities[i][j].times(dt));
        }
        }
    }
  }
  

  // This function updates the cloth using midpoint integration.
  public void updateMidpoint(float dt) {
    dt = dt/stepCount;
    for (int w = 0; w < stepCount; w++) {
        // Create copies of the current velocities and positions.
        Vec3[][] midpointVelocities = velocities;
        Vec3[][] midpointPositions = positions;
        for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            prevPositions[i][j] = new Vec3(positions[i][j]);
        }
        }
        
        // Compute the horizontal spring forces for the midpoint.
        for (int i = 0; i < height - 1; i++) {
        for (int j = 0; j < width; j++) {
            Vec3 springVector = positions[i+1][j].minus(positions[i][j]);
            float springLength = springVector.length();
            springVector.normalize();
            float v1 = dot(springVector, velocities[i][j]);
            float v2 = dot(springVector, velocities[i+1][j]);
            float force = -ks * (restLength - springLength) - kd * (v1 - v2);
            midpointVelocities[i][j].add(springVector.times(force / vertexMass * (dt/2)));
            midpointVelocities[i+1][j].subtract(springVector.times(force / vertexMass * (dt/2)));
        }
        }
        
        // Compute the vertical spring forces for the midpoint.
        for (int i = 0; i < height; i++) {
        for (int j = 0; j < width - 1; j++) {
            Vec3 springVector = positions[i][j+1].minus(positions[i][j]);
            float springLength = springVector.length();
            springVector.normalize();
            float v1 = dot(springVector, velocities[i][j]);
            float v2 = dot(springVector, velocities[i][j+1]);
            float force = -ks * (restLength - springLength) - kd * (v1 - v2);
            midpointVelocities[i][j].add(springVector.times(force / vertexMass * (dt/2)));
            midpointVelocities[i][j+1].subtract(springVector.times(force / vertexMass * (dt/2)));
        }
        }
        
        // Apply gravity and clamp the top of the cloth.
        for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            if (i == 0) { // Clamp
            midpointVelocities[i][j] = new Vec3(0, 0, 0);
            }
            else { // Gravity
            midpointVelocities[i][j].add(gravity.times(dt));
            }
        }
        }
        
        // Update the midpoint positions.
        for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            midpointPositions[i][j].add(midpointVelocities[i][j].times(dt/2));
        }
        }
        
        // Create another velocity array for the complete timestep.
        Vec3[][] finalVelocities = velocities;
        for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            finalVelocities[i][j] = velocities[i][j];
        }
        }
        
        // Compute the horizontal spring forces for the final step.
        for (int i = 0; i < height - 1; i++) {
        for (int j = 0; j < width; j++) {
            Vec3 springVector = midpointPositions[i+1][j].minus(midpointPositions[i][j]);
            float springLength = springVector.length();
            springVector.normalize();
            float v1 = dot(springVector, midpointVelocities[i][j]);
            float v2 = dot(springVector, midpointVelocities[i+1][j]);
            float force = -ks * (restLength - springLength) - kd * (v1 - v2);
            finalVelocities[i][j].add(springVector.times(force / vertexMass * dt));
            finalVelocities[i+1][j].subtract(springVector.times(force / vertexMass * dt));
        }
        }
        
        // Compute the vertical spring forces for the final step.
        for (int i = 0; i < height; i++) {
        for (int j = 0; j < width - 1; j++) {
            Vec3 springVector = midpointPositions[i][j+1].minus(midpointPositions[i][j]);
            float springLength = springVector.length();
            springVector.normalize();
            float v1 = dot(springVector, midpointVelocities[i][j]);
            float v2 = dot(springVector, midpointVelocities[i][j+1]);
            float force = -ks * (restLength - springLength) - kd * (v1 - v2);
            finalVelocities[i][j].add(springVector.times(force / vertexMass * dt));
            finalVelocities[i][j+1].subtract(springVector.times(force / vertexMass * dt));
        }
        }
        
        // Apply gravity and clamp the top of the cloth (again).
        for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            if (i == 0) { // Clamp
            finalVelocities[i][j] = new Vec3(0, 0, 0);
            }
            else { // Gravity
            finalVelocities[i][j].add(gravity.times(dt));
            }
        }
        }
        
        // Update the final velocities and positions.
        for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            positions[i][j].add(velocities[i][j].times(dt));

            Vec3 normal = nodesOnSurfaceNormals[i][j];
            if (normal != null) {
                // Exclude velocity in direction of surface
                if (dot(velocities[i][j], normal) < 0) {
                    velocities[i][j].subtract(projAB(velocities[i][j], normal));
                }
            }
            velocities[i][j] = finalVelocities[i][j];
        }
        }

        checkForCollisions();
    }
  }

  
  public void checkForCollisions() {
      for (int i = 0; i < height; i++) {
          for (int j = 0; j < width; j++) {
            Vec3 p1 = prevPositions[i][j];
            Vec3 p2 = positions[i][j];
            if (rigidBodies == null) {
                return;
            }
            Vec3 motionVec = p1.minus(p2);
            if (motionVec.length() == 0) {
                // The previous and current posiitions are the same, nothing required
                break;
            }
            Ray3 r = new Ray3(p1, motionVec, motionVec.length());
            if (debugMode) {
                r.debugDraw();
            }
            ArrayList<PShape> tris = ot.rayIntersectsOctants(r);
            CollisionInfo furthestColl = null;
            float maxT = -1;
            for (PShape tri : tris) {
                CollisionInfo coll = rayTriangleCollision(r, tri);
                if (coll != null) {
                    if (coll.t > maxT) {
                        furthestColl = coll;
                        maxT = coll.t;
                    }
                }
            }
            if (furthestColl != null) {
                if (nodesOnSurfaceNormals[i][j] == null || !nodesOnSurfaceNormals[i][j].equals(furthestColl.surfaceNormal)) {
                        // nodes[i] = furthestColl.position;
                        positions[i][j] = furthestColl.position.plus(furthestColl.surfaceNormal.times(0.01));
                        nodesOnSurfaceNormals[i][j] = furthestColl.surfaceNormal;
                }
                if (debugMode) {
                    // Show green dot where collision occurs
                    pushStyle();
                    strokeWeight(15);
                    stroke(0,255,0);
                    point(furthestColl.position.x, furthestColl.position.y, furthestColl.position.z);
                    popStyle();
                }
            } else {
                nodesOnSurfaceNormals[i][j] = null;
            }
          }
      }
  }
}