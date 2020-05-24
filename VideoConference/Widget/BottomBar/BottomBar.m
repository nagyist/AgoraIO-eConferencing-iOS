//
//  BottomBar.m
//  VideoConference
//
//  Created by SRS on 2020/5/7.
//  Copyright © 2020 agora. All rights reserved.
//

#import "BottomBar.h"
#import "MemberVC.h"
#import "MessageVC.h"
#import "SetVC.h"
#import "UserDefaults.h"
#import "ShareLinkView.h"
#import "AgoraRoomManager.h"
#import "AllMuteAlertVC.h"

@interface BottomBar()
@property (strong, nonatomic) IBOutlet BottomBar *bar;
@property (weak, nonatomic) IBOutlet BottomItem *audioItem;
@property (weak, nonatomic) IBOutlet BottomItem *videoItem;
@property (weak, nonatomic) IBOutlet BottomItem *memberItem;
@property (weak, nonatomic) IBOutlet BottomItem *imItem;
@property (weak, nonatomic) IBOutlet BottomItem *moreItem;
@end

@implementation BottomBar

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [[NSBundle mainBundle]loadNibNamed:NSStringFromClass([self class]) owner:self options:nil];
        [self addSubview:self.bar];
        [self.bar equalTo:self];
        [self initItem];
        [self initView];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self initItem];
    [self initView];
}

- (void)initItem {
    WEAK(self);
    
    self.audioItem.imageName0 = @"bar-speaker0";
    self.audioItem.imageName1 = @"bar-speaker1";
    self.audioItem.tip = Localized(@"Audio");
    self.audioItem.block = ^(){
        [weakself onSelectBar: weakself.audioItem];
    };
    
    self.videoItem.imageName0 = @"bar-camera0";
    self.videoItem.imageName1 = @"bar-camera1";
    self.videoItem.tip = Localized(@"Video");
    self.videoItem.block = ^(){
        [weakself onSelectBar: weakself.videoItem];
    };
    
    self.memberItem.imageName0 = @"bar_user0";
    self.memberItem.imageName1 = @"bar_user1";
    self.memberItem.tip = Localized(@"Member");
    self.memberItem.block = ^(){
        [weakself onSelectBar: weakself.memberItem];
    };
    
    self.imItem.imageName0 = @"bar_chat0";
    self.imItem.imageName1 = @"bar_chat1";
    self.imItem.tip = Localized(@"IM");
    self.imItem.block = ^(){
        [weakself onSelectBar: weakself.imItem];
    };
    
    self.moreItem.imageName0 = @"bar_more0";
    self.moreItem.imageName1 = @"bar_more1";
    self.moreItem.tip = Localized(@"More");
    self.moreItem.block = ^(){
         [weakself onSelectBar: weakself.moreItem];
     };
}

- (void)initView {
    self.audioItem.isSelected = [UserDefaults getOpenMic];
    self.videoItem.isSelected = [UserDefaults getOpenCamera];
}

- (void)updateView {
    ConferenceManager *manager =  AgoraRoomManager.shareManager.conferenceManager;
    
    self.audioItem.isSelected = manager.ownModel.enableAudio;
    self.videoItem.isSelected = manager.ownModel.enableVideo;
}

- (void)updateViewWithAudio:(BOOL)audio video:(BOOL)video {
    self.audioItem.isSelected = audio;
    self.videoItem.isSelected = video;
}

- (void)onSelectBar:(BottomItem *)sender {
    
    ConferenceManager *manager =  AgoraRoomManager.shareManager.conferenceManager;
    NSString *userId = manager.ownModel.userId;
    
    WEAK(self);
    
    BOOL isSelected = sender.isSelected;
    if(sender == self.audioItem || sender == self.videoItem) {
        sender.isSelected = !isSelected;
        
        EnableSignalType type = EnableSignalTypeAudio;
        if(sender == self.videoItem) {
            type = EnableSignalTypeVideo;
        }
        
        [manager updateUserInfoWithUserId:userId value:sender.isSelected enableSignalType:type successBolck:^{
            
            if(type == EnableSignalTypeVideo) {
                [NSNotificationCenter.defaultCenter postNotificationName:NOTICENAME_LOCAL_MEDIA_CHANGED object:nil];
            }
            
        } failBlock:^(NSError * _Nonnull error) {
            sender.isSelected = isSelected;
            
            [weakself showMsgToast:error.localizedDescription];
        }];
        
    } else if(sender == self.memberItem) {
        
        MemberVC *vc = [[MemberVC alloc] initWithNibName:@"MemberVC" bundle:nil];
        [VCManager pushToVC:vc];
        
    } else if(sender == self.imItem) {
        self.imItem.count = 0;
        MessageVC *vc = [[MessageVC alloc] initWithNibName:@"MessageVC" bundle:nil];
        [VCManager pushToVC:vc];
        
    } else if(sender == self.moreItem) {
        if(isSelected) {
            return;
        }
        [self onClickMore];
    }
}

- (void)onClickMore {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    WEAK(self);
    UIAlertAction *invitation = [UIAlertAction actionWithTitle:Localized(@"Invitation") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakself onClickInvitation];
    }];
    [alertController addAction:invitation];
    
    ConferenceManager *manager = AgoraRoomManager.shareManager.conferenceManager;
    if (manager.ownModel.role == ConfRoleTypeHost) {
        
        NSString *muteText = Localized(@"AllMute");
        if (manager.roomModel.muteAllAudio != MuteAllAudioStateUnmute) {
            muteText = Localized(@"AllUnmute");
        }
        
        UIAlertAction *allMute = [UIAlertAction actionWithTitle:Localized(@"muteText") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
            if (manager.roomModel.muteAllAudio == MuteAllAudioStateUnmute) {
                AllMuteAlertVC *vc = [[AllMuteAlertVC alloc] initWithNibName:@"AllMuteAlertVC" bundle:nil];
                vc.block = ^(BOOL allowUnmute) {
                    [weakself updateRoomWithState: allowUnmute ? MuteAllAudioStateAllowUnmute : MuteAllAudioStateNoAllowUnmute];
                };
                [VCManager presentToVC:vc];
            } else {
                [weakself updateRoomWithState:MuteAllAudioStateUnmute];
            }
        }];
        [alertController addAction:allMute];
    }
    
    if(NoNullString(manager.roomModel.createBoardUserId).length > 0 && manager.ownModel.role == ConfRoleTypeParticipant) {
        
        NSString *boardText = manager.ownModel.grantBoard ? Localized(@"CancelWhiteBoardControl") : Localized(@"ApplyWhiteBoard");
        
        UIAlertAction *whiteBoardControl = [UIAlertAction actionWithTitle:boardText style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
            if(!manager.ownModel.grantBoard){
                [weakself gotoApply:EnableSignalTypeGrantBoard];
            } else {
                [weakself updateWhiteBoardState];
            }
        }];
        [alertController addAction:whiteBoardControl];
    }
    
    UIAlertAction *set = [UIAlertAction actionWithTitle:Localized(@"Set") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        SetVC *vc = [[SetVC alloc] initWithNibName:@"SetVC" bundle:nil];
        vc.inMeeting = YES;
        [VCManager pushToVC:vc];
    }];
    [alertController addAction:set];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:Localized(@"Cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }];
    [alertController addAction:cancel];
    
    [VCManager presentToVC:alertController];
}

- (void)onClickInvitation {
    UIViewController *vc = [VCManager getTopVC];
    ShareLinkView *vv = [ShareLinkView createViewWithXib];
    [vv showShareLinkViewInView:vc.view];
}

- (void)showMsgToast:(NSString *)title {
    UIViewController *vc = [VCManager getTopVC];
    if (vc != nil && title != nil && title.length > 0){
        dispatch_async(dispatch_get_main_queue(), ^{
            [vc.view makeToast:title];
        });
    }
}

- (void)updateRoomWithState:(MuteAllAudioState)state {
    
    ConferenceManager *manager = AgoraRoomManager.shareManager.conferenceManager;
    
    WEAK(self);
    [manager updateRoomInfoWithValue:state enableSignalType:ConfEnableRoomSignalTypeMuteAllChat successBolck:^{

    } failBlock:^(NSError * _Nonnull error) {
        [weakself showMsgToast:error.localizedDescription];
    }];
}

- (void)gotoApply:(EnableSignalType)type {

    WEAK(self);
    ConferenceManager *manager = AgoraRoomManager.shareManager.conferenceManager;
    [manager audienceApplyWithType:EnableSignalTypeGrantBoard completeSuccessBlock:^{

    } completeFailBlock:^(NSError * _Nonnull error) {
        [weakself showMsgToast:error.localizedDescription];
    }];
}

- (void)updateWhiteBoardState {
  
    WEAK(self);
    
    ConferenceManager *manager = AgoraRoomManager.shareManager.conferenceManager;
    [manager whiteBoardStateWithValue:!manager.ownModel.grantBoard userId:manager.ownModel.userId completeSuccessBlock:^{
        
    } completeFailBlock:^(NSError * _Nonnull error) {
        [weakself showMsgToast:error.localizedDescription];
    }];
}

- (void)addUnreadMsgCount {
    NSInteger count = self.imItem.count + 1;
    self.imItem.count = count;
}

@end
