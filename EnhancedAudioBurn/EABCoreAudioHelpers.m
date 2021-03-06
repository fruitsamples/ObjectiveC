/*
 File:       EABCoreAudioHelpers.m
 
 Contains:   CoreAudio wrapper functions to help with audio file handling
 
 Version:    Technology: Mac OS X
 Release:    Mac OS X
 
 Copyright:  (c) 2006 by Apple Inc., all rights reserved
 
 Bugs?:      For bug reports, consult the following page on
 the World Wide Web:
 
 http://developer.apple.com/bugreporter/
 */
/*
 File:  EABCoreAudioHelpers.m
 
 Copyright:  © Copyright 2006 Apple Inc. All rights reserved.
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Inc.
 ("Apple") in consideration of your agreement to the following terms, and your
 use, installation, modification or redistribution of this Apple software
 constitutes acceptance of these terms.  If you do not agree with these terms,
 please do not use, install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and subject
 to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
 copyrights in this original Apple software (the "Apple Software"), to use,
 reproduce, modify and redistribute the Apple Software, with or without
 modifications, in source and/or binary forms; provided that if you redistribute
 the Apple Software in its entirety and without modifications, you must retain
 this notice and the following text and disclaimers in all such redistributions of
 the Apple Software.  Neither the name, trademarks, service marks or logos of
 Apple Inc. may be used to endorse or promote products derived from the
 Apple Software without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or implied,
 are granted by Apple herein, including but not limited to any patent rights that
 may be infringed by your derivative works or by other works in which the Apple
 Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
 WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
 WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
 COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
 OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
 (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */ 

#import <DiscRecording/DiscRecording.h>
#import "EABCoreAudioHelpers.h"

CFMutableDictionaryRef CAExtractCDTextFromAudioFile(CFStringRef inPathString)
{
	AudioFileID audioFile;
	UInt32 propsize = 0;
	CFStringRef keyStringValue;
	OSStatus result = noErr;
	CFMutableDictionaryRef	outDictionary = NULL;

	result = CreateAudioFileFromPath(inPathString, &audioFile);
	if(result != noErr)
	{
//		fprintf(stderr, "CreateAudioFileFromPath failed %d\n", (int)result);
		return NULL;
	}

	result = AudioFileGetPropertyInfo (audioFile, kAudioFilePropertyInfoDictionary, &propsize, NULL);
	if (result != noErr)
	{
//		fprintf(stderr, "kAudioFilePropertyInfoDictionary(Info) failed %d\n", (int)result);
		return NULL;
	}

	CFMutableDictionaryRef	afInfoDictionary = NULL;
	result = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &propsize, &afInfoDictionary);
	if (result != noErr)
	{
//		fprintf(stderr, "kAudioFilePropertyInfoDictionary(Info) failed %d\n", (int)result);
		return NULL;
	}

	outDictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
	if (outDictionary == NULL)
	{
//		fprintf(stderr, "CFDictionaryCreateMutable failed\n");
		return NULL;
	}

	// Composer
	if (CFDictionaryGetValueIfPresent(afInfoDictionary, CFSTR(kAFInfoDictionary_Composer), (const void **) &keyStringValue))
		CFDictionarySetValue(outDictionary, DRCDTextComposerKey, keyStringValue);

	// Title
	if (CFDictionaryGetValueIfPresent(afInfoDictionary, CFSTR(kAFInfoDictionary_Title), (const void **) &keyStringValue))
		CFDictionarySetValue(outDictionary, DRCDTextTitleKey, keyStringValue);

	// Artist
	if (CFDictionaryGetValueIfPresent(afInfoDictionary, CFSTR(kAFInfoDictionary_Artist), (const void **) &keyStringValue))
		CFDictionarySetValue(outDictionary, DRCDTextPerformerKey, keyStringValue);

	// Comments
	if (CFDictionaryGetValueIfPresent(afInfoDictionary, CFSTR(kAFInfoDictionary_Comments), (const void **) &keyStringValue))
		CFDictionarySetValue(outDictionary, DRCDTextSpecialMessageKey, keyStringValue);

	AudioFileClose(audioFile);

	return outDictionary;
}

uint64_t CAGetLengthOfAudioFile(CFStringRef inPathString)
{
	AudioFileID audioFile;
	UInt32 propsize = 0;
	OSStatus result = noErr;
	
	result = CreateAudioFileFromPath(inPathString, &audioFile);
	if(result != noErr)
	{
		fprintf(stderr, "CreateAudioFileFromPath failed %d\n", (int)result);
		return 0;
	}
	
	AudioStreamBasicDescription fileFormat;
	propsize = sizeof(fileFormat);
	result = AudioFileGetProperty(audioFile, kAudioFilePropertyDataFormat, &propsize, &fileFormat);
	if(result != noErr)
	{
		fprintf(stderr, "CAGetLengthOfAudioFile::kAudioFilePropertyDataFormat failed %d\n", (int)result);
		AudioFileClose(audioFile);
		return 0;
	}
	
	UInt64 nPackets;
	propsize = sizeof(nPackets);
	result = AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &propsize, &nPackets);
	if(result != noErr)
	{
		fprintf(stderr, "kAudioFilePropertyAudioDataPacketCount failed %d\n", (int)result);
		AudioFileClose(audioFile);
		return 0;
	}

	AudioFileClose(audioFile);
	return (nPackets * fileFormat.mFramesPerPacket) / fileFormat.mSampleRate;
}

OSStatus CreateAudioFileFromPath(CFStringRef inPathString, AudioFileID *outAudioFile)
{
	CFIndex		length = CFStringGetMaximumSizeOfFileSystemRepresentation(inPathString);
	FSRef			fileRef;
	OSStatus		result = noErr;

	char	*path = NULL;
	path = (char *) malloc(length);
    if (path == NULL)
        return EINVAL;

	if (!CFStringGetFileSystemRepresentation(inPathString, path, length))
		return EINVAL;

	result = FSPathMakeRef((UInt8 *) path, &fileRef, NULL);
	if (result == noErr)
    {
        result = AudioFileOpen (&fileRef, fsRdPerm, 0, outAudioFile);
	}
	
	return result;
 }
