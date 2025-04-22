#!/bin/bash

glslc -fshader-stage=vertex source/pukan/shaders/vertices.glsl -o vert.spv

glslc -fshader-stage=frag source/pukan/shaders/fragment.glsl -o frag.spv
