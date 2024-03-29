/*
  ==============================================================================

   This file is part of the LUBYK project (http://lubyk.org)
   Copyright (c) 2007-2010 by Gaspard Bucher - Buma (http://teti.ch).

  ------------------------------------------------------------------------------

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

  ==============================================================================
*/

// Lubyk wii::Remote
#include "wii/Remote.h"

#include "lubyk/cocoa.h"

// WiiRemoteFramework WiiRemote
#import "WiiRemote.h"

/* ======================== LWiiRemoteDelegate ===================================== */

/*

@interface NSObject( WiiRemoteDelegate )

- (void) wiimoteWillSendData;
- (void) wiimoteDidSendData;

- (void) irPointMovedX:(float) px Y:(float) py;
- (void) rawIRData: (IRData[4]) irData;
- (void) joyStickChanged:(WiiJoyStickType) type tiltX:(unsigned short) tiltX tiltY:(unsigned short) tiltY;
- (void) analogButtonChanged:(WiiButtonType) type amount:(unsigned short) press;
- (void) pressureChanged:(WiiPressureSensorType) type pressureTR:(float) bPressureTR pressureBR:(float) bPressureBR
			  pressureTL:(float) bPressureTL pressureBL:(float) bPressureBL;
- (void) batteryLevelChanged:(double) level;
- (void) gotMiiData: (Mii*) mii_data_buf at: (int) slot;
- (void) rawPressureChanged:(WiiBalanceBoardGrid) bbData;
- (void) allPressureChanged:(WiiPressureSensorType) type bbData:(WiiBalanceBoardGrid) bbData bbDataInKg:(WiiBalanceBoardGrid) bbDataInKg;

@end

*/
@interface LWiiRemoteDelegate : NSObject {
  wii::Remote *master_;
}

- (id) initWithRemote:(wii::Remote*)master;

//////// WiiRemoteDelegate ///////////
- (void) accelerationChanged:(WiiAccelerationSensorType) type accX:(unsigned short) accX accY:(unsigned short) accY accZ:(unsigned short) accZ;
- (void) buttonChanged:(WiiButtonType) type isPressed:(BOOL) isPressed;
- (void) wiiRemoteDisconnected:(IOBluetoothDevice*) device;
@end

/* ======================== LWiiRemoteDelegate @implementation ===================== */

static const char *button_name_from_type(WiiButtonType type) {
  switch (type) {
  case WiiRemoteAButton:
    return "Remote.A";
  case WiiRemoteBButton:
    return "Remote.B";
  case WiiRemoteOneButton:
    return "Remote.1";
  case WiiRemoteTwoButton:
    return "Remote.2";
  case WiiRemoteMinusButton:
    return "Remote.-";
  case WiiRemoteHomeButton:
    return "Remote.H";
  case WiiRemotePlusButton:
    return "Remote.+";
  case WiiRemoteUpButton:
    return "Remote.U";
  case WiiRemoteDownButton:
    return "Remote.D";
  case WiiRemoteLeftButton:
    return "Remote.L";
  case WiiRemoteRightButton:
    return "Remote.R";

  case WiiNunchukZButton:
    return "Nunchuk.Z";
  case WiiNunchukCButton:
    return "Nunchuk.C";

  case WiiClassicControllerXButton:
    return "Classic.X";
  case WiiClassicControllerYButton:
    return "Classic.Y";
  case WiiClassicControllerAButton:
    return "Classic.A";
  case WiiClassicControllerBButton:
    return "Classic.B";
  case WiiClassicControllerLButton:
    return "Classic.L";
  case WiiClassicControllerRButton:
    return "Classic.R";
  case WiiClassicControllerZLButton:
    return "Classic.ZL";
  case WiiClassicControllerZRButton:
    return "Classic.ZR";
  case WiiClassicControllerUpButton:
    return "Classic.U";
  case WiiClassicControllerDownButton:
    return "Classic.D";
  case WiiClassicControllerLeftButton:
    return "Classic.L";
  case WiiClassicControllerRightButton:
    return "Classic.R";
  case WiiClassicControllerMinusButton:
    return "Classic.-";
  case WiiClassicControllerHomeButton:
    return "Classic.H";
  case WiiClassicControllerPlusButton:
    return "Classic.+";
  default:
    return "???";
  }
}

@implementation LWiiRemoteDelegate
- (id) initWithRemote:(wii::Remote*)master {
  self = [super init];
  if (self) {
    master_ = master;
  }
  return self;
}

- (void) accelerationChanged:(WiiAccelerationSensorType) type accX:(unsigned short) accX accY:(unsigned short) accY accZ:(unsigned short) accZ {
  master_->acceleration(
    type == WiiRemoteAccelerationSensor ? "Remote" : "Nunchuk",
    (float)accX / 0xff,
    (float)accY / 0xff,
    (float)accZ / 0xff
  );
}

- (void) buttonChanged:(WiiButtonType) type isPressed:(BOOL) isPressed {
  master_->button(
    button_name_from_type(type),
    isPressed
  );
}

- (void) wiiRemoteDisconnected:(IOBluetoothDevice*) device {
  master_->disconnected();
}

@end // LWiiRemoteDelegate


/* ======================== wii::Remote ======================== */

namespace wii {

class Remote::Implementation
{
  Remote *master_;
  WiiRemote *wii_remote_;
  LWiiRemoteDelegate *wii_remote_delegate_;
public:
  Implementation(Remote *master)
   : master_(master) {
    wii_remote_delegate_ = [[LWiiRemoteDelegate alloc] initWithRemote:master_];
    wii_remote_ = nil;
  }

  void setRemote(WiiRemote *remote) {
    if (wii_remote_ == remote) return;

    unlinkWii();

    wii_remote_ = [remote retain];
  	[wii_remote_ setDelegate:wii_remote_delegate_];
  	master_->name_ = [[remote address] UTF8String];
    master_->connected();
  }

  void setLeds(bool led1, bool led2, bool led3, bool led4) {
    [wii_remote_ setLEDEnabled1:led1 enabled2:led2 enabled3:led3 enabled4:led4];
  }

  void unlinkWii() {
    if (wii_remote_) {
      [wii_remote_ closeConnection];
      [wii_remote_ release];
      wii_remote_ = nil;
    }
  }

  ~Implementation() {
    unlinkWii();

    [wii_remote_delegate_ release];
  }
};

Remote::Remote(const char *remote_name) {
  ScopedPool pool;
  if (remote_name) name_ = remote_name;
  impl_ = new Implementation(this);
}

Remote::~Remote() {
  delete impl_;
}

void Remote::setRemote(void *remote) {
  impl_->setRemote((WiiRemote *)remote);
}

void Remote::setLeds(bool led1, bool led2, bool led3, bool led4) {
  impl_->setLeds(led1, led2, led3, led4);
}

void Remote::disconnect() {
  impl_->unlinkWii();
}

} // wii


// One compilation unit to cope with static _mii_data_buf.

/* ================================================================================================== BROWSER */

// Lubyk wii::Browser
#include "wii/Browser.h"
#include "wii/Remote.h"

#include "lubyk/cocoa.h"

// WiiRemoteFramework WiiRemoteDiscovery
#import "WiiRemoteDiscovery.h"

/* ======================== LWiiDiscoveryDelegate ===================================== */
@interface LWiiDiscoveryDelegate : NSObject {
  wii::Browser *master_;
  lubyk::Worker *worker_;
}

- (id) initWithBrowser:(wii::Browser*)master worker:(lubyk::Worker*) worker;

//////// WiiDiscoveryDelegate ///////////

- (void) WiiRemoteDiscovered:(WiiRemote*)wiimote;
- (void) WiiRemoteDiscoveryError:(int)code;
- (void) WiiRemoteStopped;
@end

/* ======================== LWiiDiscoveryDelegate @implementation ===================== */

@implementation LWiiDiscoveryDelegate

- (id) initWithBrowser:(wii::Browser*)master worker:(lubyk::Worker*) worker {
  self = [super init];

  if (self) {
    master_ = master;
    worker_ = worker;
  }
  return self;
}

- (void) willStartWiimoteConnections {
  // do nothing
}

// They appear one at a time so we have to restart if we need more.
- (void) WiiRemoteDiscovered:(WiiRemote*)wiimote {
  // get a wii.Remote and connect
  wii::Remote *remote = master_->found([[wiimote address] UTF8String]);
  if (remote) {
    remote->setRemote(wiimote);
  } else {
    fprintf(stderr, "Could not connect..\n");
  }

  if (master_->needMore()) {
    master_->findMore();
  }
}

- (void) WiiRemoteDiscoveryError:(int)code {
  fprintf(stderr, "WiiRemoteDiscoveryError %i\n", code);
}

- (void) WiiRemoteStopped {
  if (master_->needMore()) {
    master_->findMore();
  }
}

@end // LWiiDiscoveryDelegate

/* ======================== wii::Browser::Implementation ======================= */
namespace wii {

class Browser::Implementation
{
  Browser *master_;
  LWiiDiscoveryDelegate *wii_discovery_delegate_;
	WiiRemoteDiscovery *discovery_;
public:
  Implementation(Browser *master)
   : master_(master) {
    wii_discovery_delegate_ = [[LWiiDiscoveryDelegate alloc] initWithBrowser:master_ worker:master_->worker_];
    discovery_ = [[WiiRemoteDiscovery alloc] init];
    [discovery_ setDelegate:wii_discovery_delegate_];
    //discovery_ =  [WiiRemoteDiscovery discoveryWithDelegate:wii_discovery_delegate_];
    //[discovery_ retain];
  }

  ~Implementation() {
    ScopedPool pool;
    [discovery_ stop];
  	[discovery_ release];
    [wii_discovery_delegate_ release];
  }

  // called each time we need more wiimotes
  void find() {
    ScopedPool pool;
    // TODO: Mutex?
    if (![discovery_ isDiscovering]) {
      IOReturn ret = [discovery_ start];
      if (ret != kIOReturnSuccess) {
        fprintf(stderr, "Error starting wii Browser.\n");
      }
    }
  }
};

Browser::Browser()
    : need_count_(0),
      need_more_(false) {
  ScopedPool pool;
  // we need to run the browser in an NSThread
  // or something else that has an event loop so that we
  // get IO...
  // My idea here would be to create a thread with [NSApp run] in the worker
  // if we are on OS X...
  // http://lists.apple.com/archives/Bluetooth-dev/2006/Mar/msg00006.html
  impl_ = new Implementation(this);
}

Browser::~Browser() {
  delete impl_;
}

// called by Lua on new wii.Remote
void Browser::find() {
  need_count_++;
  impl_->find();
}

// called by objC
void Browser::findMore() {
  impl_->find();
}

} // wii
