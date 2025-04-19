#!/bin/bash

glslc -fshader-stage=vertex source/shaders/vertices.glsl -o vert.spv

glslc -fshader-stage=frag source/shaders/fragment.glsl -o frag.spv
