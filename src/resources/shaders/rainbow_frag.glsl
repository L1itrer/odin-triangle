#version 450 core

in vec4 vertColor;
in vec2 texCoord;

uniform vec4 dtColor;
uniform float faceVisibility;

uniform sampler2D texture1;
uniform sampler2D texture2;




out vec4 outColor;

void main()
{
  vec4 baseColor = vertColor;
  vec4 supColor = (dtColor / 2) + 0.5;
  //outColor = texture(ourTexture, texCoord) * baseColor * supColor ;//mix(baseColor, dtColor, 0.2);//vec4(vertColor, 1.0);
  outColor = mix(
    texture(texture1, texCoord) * baseColor * supColor,
    texture(texture2, vec2(-texCoord.x, texCoord.y)),
    faceVisibility
  );
}
