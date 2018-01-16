//
//  iOSCoreAudio.mm
//  iNDS
//
//  Created by Zydeco on 3/7/2013.
//  Copyright (c) 2013 Homebrew. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#include "SPU.h"
#include "iOSCoreAudio.h"
#include "main.h"

#define NUM_BUFFERS 2

static int curFillBuffer = 0;
static int curReadBuffer = 0;
static int numFullBuffers = 0;
static u32 sndBufferSize;
static s16 *sndBuffer[NUM_BUFFERS];
static bool audioQueueStarted = false;
static AudioQueueBufferRef aqBuffer[NUM_BUFFERS];
static AudioQueueRef audioQueue;

void SNDCoreAudioCallback(void *data, AudioQueueRef mQueue, AudioQueueBufferRef mBuffer) {
    mBuffer->mAudioDataByteSize = sndBufferSize;
    void *mAudioData = mBuffer->mAudioData;
    if (numFullBuffers == 0) {
        bzero(mAudioData, sndBufferSize);
    } else {
        memcpy(mAudioData, sndBuffer[curReadBuffer], sndBufferSize);
        numFullBuffers--;
        curReadBuffer = curReadBuffer ? 0 : 1;
    }
    AudioQueueEnqueueBuffer(mQueue, mBuffer, 0, NULL);
}

int SNDCoreAudioInit(u32 buffersize) {
    OSStatus err;
    curReadBuffer = curFillBuffer = numFullBuffers = 0;

    // create queue
    AudioStreamBasicDescription outputFormat;
	memset(&outputFormat, 0, sizeof(outputFormat));
	outputFormat.mSampleRate = DESMUME_SAMPLE_RATE;
	outputFormat.mFormatID = kAudioFormatLinearPCM;
	outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	outputFormat.mBitsPerChannel = sizeof(short) * 8;
	outputFormat.mChannelsPerFrame = 2;
	outputFormat.mFramesPerPacket = 1;
	outputFormat.mBytesPerFrame = (outputFormat.mBitsPerChannel / 8) * outputFormat.mChannelsPerFrame;
	outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
    err = AudioQueueNewOutput(&outputFormat, SNDCoreAudioCallback, NULL, CFRunLoopGetMain(), kCFRunLoopCommonModes, 0, &audioQueue);
    if (err != noErr) return -1;

    // create buffers
    sndBufferSize = buffersize;
    for (int i=0; i<NUM_BUFFERS; i++) {
        AudioQueueAllocateBuffer(audioQueue, sndBufferSize, &aqBuffer[i]);
        SNDCoreAudioCallback(NULL, audioQueue, aqBuffer[i]);
        sndBuffer[i] = (s16*)malloc(sndBufferSize);
    }

    audioQueueStarted = false;

    return 0;
}

void SNDCoreAudioDeInit() {
    AudioQueueStop(audioQueue, true);

    for (int i=0; i<NUM_BUFFERS; i++) {
        AudioQueueFreeBuffer(audioQueue, aqBuffer[i]);
        free(sndBuffer[i]);
    }

    AudioQueueFlush(audioQueue);
    AudioQueueDispose(audioQueue, true);
}

void SNDCoreAudioUpdateAudio(s16 *buffer, u32 num_samples) {
    if (numFullBuffers == NUM_BUFFERS) return;
    memcpy(sndBuffer[curFillBuffer], buffer, 4 * num_samples);
    curFillBuffer = curFillBuffer ? 0 : 1;
    numFullBuffers++;
    if (!audioQueueStarted) {
        audioQueueStarted = true;
        AudioQueueStart(audioQueue, NULL);
    }
}

u32 SNDCoreAudioGetAudioSpace() {
    if (numFullBuffers == NUM_BUFFERS) return 0;
    return (sndBufferSize / 4);
}

void SNDCoreAudioMuteAudio() {
    AudioQueueStop(audioQueue, false);
}

void SNDCoreAudioUnMuteAudio() {
    AudioQueueStart(audioQueue, NULL);
}

void SNDCoreAudioSetVolume(int volume) {

}

SoundInterface_struct SNDCoreAudio = {
	SNDCORE_COREAUDIO,
	"CoreAudio Sound Interface",
	SNDCoreAudioInit,
	SNDCoreAudioDeInit,
	SNDCoreAudioUpdateAudio,
	SNDCoreAudioGetAudioSpace,
	SNDCoreAudioMuteAudio,
	SNDCoreAudioUnMuteAudio,
	SNDCoreAudioSetVolume,
};
