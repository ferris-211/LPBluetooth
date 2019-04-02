//
//  LPBluetoothModel.h
//  LPBluetoothDemo
//
//  Created by Ferris on 2019/3/25.
//  Copyright © 2019年 LP. All rights reserved.
//

#import <Foundation/Foundation.h>

//蓝牙外设特征
@interface LPBluetoothModel : NSObject

@property(nonatomic,copy) NSString *name;       //设备显示名称
@property(nonatomic,copy) NSString *sUUID;      //Service UUID
@property(nonatomic,copy) NSString *crUUID;     //Characteristic UUID(Read Data)
@property(nonatomic,copy) NSString *cwUUID;     //Characteristic UUID(Write Data)

@end
