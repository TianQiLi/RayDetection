#include <OpenGLES/ES1/gl.h>
#include <OpenGLES/ES1/glext.h>
#include "IRenderingEngine.hpp"
#include "Quaternion.hpp"
#include <vector>
#include "data.hpp"
#include "MCGL.h"
#include "MCRay.h"
#include <iostream>

static const float AnimationDuration = 0.25f;

using namespace std;

struct Vertex {
    vec3 Position;
    vec4 Color;
};

struct Animation {
    Quaternion Start;
    Quaternion End;
    Quaternion Current;
    float Elapsed;
    float Duration;
};

class RenderingEngine1 : public IRenderingEngine {
public:
    RenderingEngine1();
    void Initialize(int width, int height);
    void Render();
    void UpdateAnimation(float timeStep);
    void OnRotate(DeviceOrientation newOrientation);
    void OnFingerUp(ivec2 location);
    void OnFingerDown(ivec2 location);
    void OnFingerMove(ivec2 oldLocation,ivec2 newLocation);
    vec3 MapToSphere(ivec2 touchpoint) const;
private:
    float m_trackballRadius;
  
    ivec2 m_screenSize;
    ivec2 m_centerPoint;

    ivec2 m_fingerStart;
    bool m_spinning;
    Quaternion m_orientation;
    Quaternion m_previousOrientation;
    
    
    
   
    //handle of vertex data in opengl memory
    GLuint m_cubeVertexBuffer;
    GLuint m_cubeIndexBuffer;
    GLuint m_cubeIndexCount;
  
    //
    GLuint m_depthRenderbuffer;
    
    

      
    GLuint m_framebuffer;
    GLuint m_colorRenderbuffer;
    
    MCRay *ray;
    
};

IRenderingEngine* CreateRenderer1()
{
    return new RenderingEngine1();
}

RenderingEngine1::RenderingEngine1():m_spinning(false)
{
    // Create & bind the color buffer so that the caller can allocate its space.
    glGenRenderbuffersOES(1, &m_colorRenderbuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_colorRenderbuffer);
}

void RenderingEngine1::Initialize(int width, int height)
{
    ray = [[MCRay alloc] init];
    
        m_trackballRadius = width / 3;
    
        m_screenSize = ivec2(width, height);
        m_centerPoint = m_screenSize / 2;

    
        //init my cube
    
        vector<Vertex>m_cube(24);
//        m_cube.resize(24);
        
        vector<Vertex>::iterator vertex = m_cube.begin();
        for (int i =0,j=0,k=0; vertex != m_cube.end();k++, vertex++,i=i+3) {
            vertex->Position.x = cubeVertices[i];
            vertex->Position.y = cubeVertices[i+1];
            vertex->Position.z = cubeVertices[i+2];
            j=k/4;
            j=4*j;
            vertex->Color = vec4(colorss[j],colorss[j+1],colorss[j+2],colorss[j+3]);
        }
    
    //creat index
    
        vector<GLubyte>m_cubeIndices(72);
        m_cubeIndexCount = 72;
        m_cubeIndices.resize(72);
        vector<GLubyte>::iterator index = m_cubeIndices.begin();
        for (int i = 0 ; i<72; i++) {
            *index++=i;
        }
    
    
    // Create the depth buffer.
    glGenRenderbuffersOES(1, &m_depthRenderbuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_depthRenderbuffer);
    glRenderbufferStorageOES(GL_RENDERBUFFER_OES,
                             GL_DEPTH_COMPONENT16_OES,
                             width,
                             height);
    
    
    // Create the framebuffer object; attach the depth and color buffers.
    glGenFramebuffersOES(1, &m_framebuffer);
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, m_framebuffer);
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES,
                                 GL_COLOR_ATTACHMENT0_OES,
                                 GL_RENDERBUFFER_OES,
                                 m_colorRenderbuffer);
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES,
                                 GL_DEPTH_ATTACHMENT_OES,
                                 GL_RENDERBUFFER_OES,
                                 m_depthRenderbuffer);
    
    // Bind the color buffer for rendering.
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_colorRenderbuffer);
   
    //creat the VBO for vertices
    glGenBuffers(1, &m_cubeVertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, m_cubeVertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, m_cube.size()*sizeof(m_cube[0]), &m_cube[0], GL_STATIC_DRAW);
    //creat the VBO for indices
    glGenBuffers(1, &m_cubeIndexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_cubeIndexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, m_cubeIndices.size()*sizeof(m_cubeIndices[0]), &m_cubeIndices[0], GL_STATIC_DRAW);
    
    glViewport(0, 0, width, height);
    glEnable(GL_DEPTH_TEST);
    
    //You can see that instead of glMatrixMode(GL_PROJECTION) you use this function.
    [MCGL matrixMode:GL_PROJECTION];
    
    //You can see that instead of glLoadIdentity() you use this function.
    [MCGL loadIdentity];
    
    //Here, you can use this advanced function to set the projection matrix.
    [MCGL perspectiveWithFovy:51.0
                       aspect:(float)width/(float)height
                        zNear:5
                         zFar:10];
    
    
}

void RenderingEngine1::Render()
{
    
    glClearColor(0.5f, 0.5f, 0.5f, 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    // Set the model-view transform.
    
    [MCGL matrixMode:GL_MODELVIEW];
    [MCGL loadIdentity];
    
    //Set the eye's position.
    //What you should remember is that before you set the eye, you should reset the matrix.
    //Otherwise, the positon is in the model coordinate.
    [MCGL lookAtEyefv:vec3(0.0, 0.0, 7.0)
             centerfv:vec3(0.0, 0.0, 0.0)
                 upfv:vec3(0.0, 1.0, 0.0)];
    
    //Here, set the rotation
    [MCGL rotateWithQuaternion:m_orientation];
    
    
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_COLOR_ARRAY);


    
    
    const GLvoid* colorOffset = (GLvoid*)sizeof(vec3);
    glBindBuffer(GL_ARRAY_BUFFER, m_cubeVertexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_cubeIndexBuffer);
  
    
    glVertexPointer(3, GL_FLOAT, sizeof(Vertex), 0);
    glColorPointer(4, GL_FLOAT, sizeof(Vertex), colorOffset);
    
   
       for(int i = 0;i<6;i++){
        glDrawElements(GL_TRIANGLE_FAN, 4, GL_UNSIGNED_BYTE, (GLvoid*)(i*4));
    }
    
    
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);

    //glPopMatrix();
}

void RenderingEngine1::UpdateAnimation(float timeStep)
{
}

void RenderingEngine1::OnRotate(DeviceOrientation orientation)
{

}

void RenderingEngine1::OnFingerUp(ivec2 location){
    m_spinning = false;
}


void RenderingEngine1::OnFingerDown(ivec2 location){
    //Once function down, update the ray.
    [ray updateWithScreenX:location.x
                   screenY:location.y];
    //Find the inverse of the model matrix
    mat4 tmp;
    glhInvertMatrixf2([MCGL getCurrentModelMatrix].Pointer(), &(tmp.x.x));
    //Transform the ray by the inverse matrix.
    [ray transformWithMatrix:tmp];
    //three vertexs of the triangle, just for test.
    float V0[3] = {-1.0,1.0,1.0};
    float V1[3] = {-1.0,-1.0,1.0};
    float V2[3] = {1.0,-1.0,1.0};
    //OK, check the intersection and return the distance.
    float distance = [ray intersectWithTriangleMadeUpOfV0:V0
                                                   V1:V1
                                                   V2:V2];
    //print it.
    NSLog(@"%f",distance);
    
    m_fingerStart = location;
    m_previousOrientation = m_orientation;
      m_spinning = true;

    OnFingerMove(location, location);
}
void RenderingEngine1::OnFingerMove(ivec2 oldLocation, ivec2 newLocation){
    if (m_spinning) {
        vec3 start = MapToSphere(m_fingerStart);
        vec3 end = MapToSphere(newLocation);
        Quaternion delta = Quaternion::CreateFromVectors(start, end);
        m_orientation = delta.Rotated(m_previousOrientation);
        
    }


}
vec3 RenderingEngine1::MapToSphere(ivec2 touchpoint) const
{
    vec2 p = touchpoint - m_centerPoint;
    
    // Flip the Y axis because pixel coords increase towards the bottom.
    p.y = -p.y;
    
    const float radius = m_trackballRadius;
    const float safeRadius = radius - 1;
    
    if (p.Length() > safeRadius) {
        float theta = atan2(p.y, p.x);
        p.x = safeRadius * cos(theta);
        p.y = safeRadius * sin(theta);
    }
    
    float z = sqrt(radius * radius - p.LengthSquared());
    vec3 mapped = vec3(p.x, p.y, z);
    return mapped / radius;
}


