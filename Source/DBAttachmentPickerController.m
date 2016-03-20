//
//  DBAttachmentPickerController.m
//  DBAttachmentPickerController
//
//  Created by Denis Bogatyrev on 14.03.16.
//
//  The MIT License (MIT)
//  Copyright (c) 2016 Denis Bogatyrev.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

@import Photos;
#import <MobileCoreServices/UTCoreTypes.h>
#import "DBAttachmentPickerController.h"
#import "DBAttachmentAlertController.h"
#import "DBAttachment.h"
#import "DBAssetPickerController.h"

@interface DBAttachmentPickerController () <UIDocumentMenuDelegate, UIDocumentPickerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, DBAssetPickerControllerDelegate>

@property (strong, nonatomic) UIViewController *initialViewController;
@property (assign, nonatomic) DBAttachmentPickerControllerMediaType mediaType;
@property (strong, nonatomic) DBAttachmentAlertController *alertController;

@end

@implementation DBAttachmentPickerController

#pragma mark - Class methods

- (instancetype)initWithMediaType:(DBAttachmentPickerControllerMediaType)mediaType {
    self = [super init];
    if (self) {
        self.mediaType = mediaType;
    }
    return self;
}

- (void)dealloc {
    [self.alertController dismissViewControllerAnimated:YES completion:^{
        NSLog(@"Error: Responder must retain pickerController instance");
    }];
}

#pragma mark - Public

- (void)presentAttachmentPickerOnViewController:(UIViewController *)initialViewController {
    self.initialViewController = initialViewController;
    __weak typeof(self) weakSelf = self;
    self.alertController = [DBAttachmentAlertController attachmentAlertControllerWithMediaType:[self assetMediaType]
                                                           attachHandler:^(NSArray<PHAsset *> *assetArray) {
                                                               NSArray<DBAttachment *> *attachmentArray = [weakSelf attachmentArrayFromPHAssetArray:assetArray];
                                                               [weakSelf finishPickingWithAttachmentArray:attachmentArray];
                                                           } allAlbumsHandler:^(UIAlertAction *action) {
                                                               [weakSelf allAlbumsDidSelect];
                                                           } takePictureHandler:^(UIAlertAction *action) {
                                                               [weakSelf takePictureButtonDidSelect];
                                                           } otherAppsHandler:^(UIAlertAction *action) {
                                                               [weakSelf otherAppsButtonDidSelect];
                                                           } cancelHandler:^(UIAlertAction * _Nonnull action) {
                                                               [weakSelf cancelDidSelect];
                                                           }];

    [self.initialViewController presentViewController:self.alertController animated:YES completion:^{
        weakSelf.alertController = nil;
    }];
}

#pragma mark Helpers

- (PHAssetMediaType)assetMediaType {
    switch (self.mediaType) {
        case DBAttachmentPickerControllerMediaTypeVideo:
            return PHAssetMediaTypeVideo;
            break;
        default:
            return PHAssetMediaTypeImage;
            break;
    }
}

- (NSArray<DBAttachment *> *)attachmentArrayFromPHAssetArray:(NSArray<PHAsset *> *)assetArray {
    NSMutableArray *attachmentArray = [NSMutableArray arrayWithCapacity:assetArray.count];
    for (PHAsset *asset in assetArray) {
        DBAttachment *model = [DBAttachment attachmentFromPHAsset:asset];
        [attachmentArray addObject:model];
    }
    return [attachmentArray copy];
}

#pragma mark - Actions

- (void)allAlbumsDidSelect {
    DBAssetPickerController *viewController =[[DBAssetPickerController alloc] init];
    viewController.assetMediaType = [self assetMediaType];
    viewController.assetPickerDelegate = self;
    
    [self.initialViewController presentViewController:viewController animated:YES completion:nil];
}

- (void)otherAppsButtonDidSelect {
    NSArray *documentMediaTypes = nil;
    switch (self.mediaType) {
        case DBAttachmentPickerControllerMediaTypeVideo:
            documentMediaTypes = @[(NSString *)kUTTypeMovie, (NSString *)kUTTypeVideo];
            break;
        default:
            documentMediaTypes = @[(NSString *)kUTTypeImage];
            break;
    }
    
    UIDocumentMenuViewController *viewController = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:documentMediaTypes inMode:UIDocumentPickerModeImport];
    viewController.delegate = self;
    viewController.modalPresentationStyle = UIModalPresentationFullScreen;
    [self.initialViewController presentViewController:viewController animated:YES completion:nil];
}

- (void)takePictureButtonDidSelect {
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:@"Device has no camera" preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *actionCancel = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:actionCancel];
        
        [self.initialViewController presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.allowsEditing = NO;
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    switch (self.mediaType) {
        case DBAttachmentPickerControllerMediaTypeVideo:
            picker.mediaTypes = @[(NSString *)kUTTypeMovie, (NSString *)kUTTypeVideo];
            picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
            break;
        default:
            picker.mediaTypes = @[(NSString *)kUTTypeImage];
            picker.cameraCaptureMode = UIImagePickerControllerCameraCaptureModePhoto;
            break;
    }
    
    [self.initialViewController presentViewController:picker animated:YES completion:nil];
}

#pragma mark

- (void)finishPickingWithAttachmentArray:(NSArray <DBAttachment *> *)attachmentArray {
    if ([self.delegate respondsToSelector:@selector(DBAttachmentPickerController:didFinishPickingAttachmentArray:)]) {
        [self.delegate DBAttachmentPickerController:self didFinishPickingAttachmentArray:attachmentArray];
    }
}

- (void)cancelDidSelect {
    if ([self.delegate respondsToSelector:@selector(DBAttachmentPickerControllerDidCancel:)]) {
        [self.delegate DBAttachmentPickerControllerDidCancel:self];
    }
}

#pragma mark - UIDocumentMenuViewControllerDelegate

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker {
    documentPicker.delegate = self;
    [self.initialViewController presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu {
    [self cancelDidSelect];
}

#pragma mark - UIDocumentPickerViewControllerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url {
    DBAttachment *attachment = [DBAttachment attachmentFromDocumentURL:url withMediaType:DBAttachmentPickerControllerMediaTypeImage];
    [self finishPickingWithAttachmentArray:@[attachment]];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    [self cancelDidSelect];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *mediaType = info[UIImagePickerControllerMediaType];
    NSArray *attachmentArray = @[];
    if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) {
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        DBAttachment *attachment = [DBAttachment attachmentFromImage:image];
        attachmentArray = @[attachment];
    } else if ([mediaType isEqualToString:(NSString *)kUTTypeMovie] || [mediaType isEqualToString:(NSString *)kUTTypeVideo]) {
        NSURL *documentURL = info[UIImagePickerControllerMediaURL];
        if (documentURL) {
            DBAttachment *attachment = [DBAttachment attachmentFromDocumentURL:documentURL withMediaType:DBAttachmentPickerControllerMediaTypeVideo];
            attachmentArray = @[attachment];
        }
    }
    
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        [weakSelf finishPickingWithAttachmentArray:attachmentArray];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        [weakSelf cancelDidSelect];
    }];
}

#pragma mark - DBImagePickerControllerDelegate

- (void)DBAssetPickerController:(nonnull DBAssetPickerController *)controller didFinishPickingAssetArray:(nonnull NSArray<PHAsset *> *)assetArray {
    __weak typeof(self) weakSelf = self;
    [controller dismissViewControllerAnimated:YES completion:^{
        NSArray<DBAttachment *> *attachmentArray = [weakSelf attachmentArrayFromPHAssetArray:assetArray];
        [weakSelf finishPickingWithAttachmentArray:attachmentArray];
    }];
}

- (void)DBAssetPickerControllerDidCancel:(nonnull DBAssetPickerController *)controller {
    __weak typeof(self) weakSelf = self;
    [controller dismissViewControllerAnimated:YES completion:^{
        [weakSelf cancelDidSelect];
    }];
}

@end