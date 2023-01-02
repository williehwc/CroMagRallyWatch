//
//  CroMagRally.hpp
//  CroMagRallyWatch WatchKit Extension
//
//  Created by Willie Chang on 12/12/22.
//

#ifndef CroMagRally_hpp
#define CroMagRally_hpp

#include "zbuffer.h"

enum
{
    INPUT_FLAG_UP    = 1,
    INPUT_FLAG_DN    = 2,
    INPUT_FLAG_FWRD  = 4,
    INPUT_FLAG_BWRD  = 8,
    INPUT_FLAG_PAUSE = 16,
    INPUT_FLAG_ESC   = 32,
    INPUT_FLAG_OK    = 64
};

//const int RED = 0;
//const int GRN = 1;
//const int BLU = 2;

const int NUM_GRPHICS_CHANNELS = 4;

const int WIDTH  = 320;
const int HEIGHT = 390;

const int NUM_GRAPHICS_BYTES = HEIGHT * WIDTH * NUM_GRPHICS_CHANNELS;

const int NUM_SAMPLES = 4096;

extern PIXEL* gPixels;
extern bool gPixelsReady;

extern Byte gInputFlags;
extern bool gInputDecel;
extern bool gInputBrake;
extern float gInputSteer;
extern bool gCanSteer;
extern bool gCrashThud;

void GameThread(std::string dataPath);
void GetAudio(float *const *stream, int len);

#endif /* CroMagRally_hpp */
