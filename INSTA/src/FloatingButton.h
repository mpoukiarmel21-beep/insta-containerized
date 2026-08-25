//
//  FloatingButton.h
//  Containerizer (Instagram tweak)
//  Bouton flottant draggable + menu conteneurs.
//  Ré-installé sur keyWindow à chaque didBecomeActive.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface FloatingButton : NSObject
+ (instancetype)shared;
- (void)show;
@end
