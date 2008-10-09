/* enfuseController */

#import <Cocoa/Cocoa.h>
#import "CTProgressBadge.h"
#import "TaskWrapper.h"
#import "MyPrefsWindowController.h"

@interface enfuseController : NSObject <TaskWrapperController>
{
  IBOutlet NSWindow *window;
  IBOutlet NSSlider* mContrastSlider;
  IBOutlet NSStepper* mContrastStepper;
  IBOutlet NSTextField* mContrastTextField;
  IBOutlet NSSlider* mExposureSlider;
  IBOutlet NSStepper* mExposureStepper;
  IBOutlet NSTextField* mExposureTextField;
  IBOutlet NSSlider* mSaturationSlider;
  IBOutlet NSStepper* mSaturationStepper;
  IBOutlet NSTextField* mSaturationTextField;
  IBOutlet NSTableView* mTableImage;
  IBOutlet NSButton* mCancelButton;
  IBOutlet NSButton* mResetButton;
  IBOutlet NSButton* mEnfuseButton;

  IBOutlet NSSlider* mMuSlider;
  IBOutlet NSStepper* mMuStepper;
  IBOutlet NSTextField* mMuTextField;

  IBOutlet NSSlider* mSigmaSlider;
  IBOutlet NSStepper* mSigmaStepper;
  IBOutlet NSTextField* mSigmaTextField;

  // expert options ...
  IBOutlet NSTextField* mContrastWindowSizeTextField;
  IBOutlet NSTextField* mMinCurvatureTextField;
  
  // ouput options
  IBOutlet NSTextField *mOuputFile;
  IBOutlet NSPopUpButton *mOutFormat;
  IBOutlet NSTextField *mOutQuality;
  IBOutlet NSTextField *mOutFile;
  IBOutlet NSTextField *mAppendTo;
  IBOutlet NSMatrix *mOutputType;
  IBOutlet NSSlider *mOutputQualitySlider; 
  
  IBOutlet NSArrayController *mImageArrayCtrl;

  // open file ?
  IBOutlet NSMatrix *mDoAfter;
  
  // metadata ... 
  IBOutlet NSButton* mCopyMeta;
  IBOutlet NSButton* mCopyAperture;
  IBOutlet NSButton* mCopyShutter;
  IBOutlet NSButton* mCopyFocal;

#ifndef GNUSTEP
  CTProgressBadge *myBadge;
#endif

  IBOutlet NSProgressIndicator *mProgress;

  @private
    BOOL findRunning;
    TaskWrapper *enfuseTask;

    NSString* _outputfile;
    NSString* _tmpfile;

    NSMutableArray *images;

    NSMutableDictionnary *_imageCacheData;
	
#ifndef GNUSTEP
    int value;
#endif
}

- (IBAction) cancel: (IBOutlet)sender;
- (IBAction) reset: (IBOutlet)sender;
- (IBAction) enfuse: (IBOutlet)sender;
- (IBAction) about: (IBOutlet)sender;
- (IBAction) chooseOutputDirectory: (IBOutlet)sender;
- (IBAction) takeSaturation: (IBOutlet)sender;
- (IBAction) quit: (IBOutlet)sender;
- (IBAction) takeContrast: (IBOutlet)sender;
- (IBAction) takeExposure: (IBOutlet)sender;
- (IBAction) addImage: (IBOutlet)sender;

- (IBAction) takeSigma: (IBOutlet)sender;
- (IBAction) takeMu: (IBOutlet)sender;

- (IBAction) revealInFinder:(IBOutlet)sender;

-(NSString*)outputfile;
-(void)setOutputfile:(NSString *)file;
-(NSString*)tempfile;
-(void)setTempfile:(NSString *)file;

- (IBAction)openPreferences:(id)sender;

- (IBAction) openPresets: (IBOutlet)sender;
- (IBAction) savePresets: (IBOutlet)sender;

@end
