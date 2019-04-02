//
//  LPBluetoothManager.h
//  LPBluetoothDemo
//
//  Created by Ferris on 2019/3/25.
//  Copyright © 2019年 LP. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "LPBluetoothModel.h"

typedef NS_ENUM(NSUInteger, LPBluetoothManagerStatus) {
    LPBluetoothManagerWait = 0,
    LPBluetoothManagerScanning,
    LPBluetoothManagerConnecting,
    LPBluetoothManagerConnected
};

@interface LPBluetoothPeripheral: NSObject

@property(nonatomic,strong) CBPeripheral *peripheral;
@property(nonatomic,copy) NSNumber *RSSI;
@property(nonatomic,copy) NSDictionary *advertisementData;

@end

@protocol LPBluetoothManagerDelegate;

@interface LPBluetoothManager : NSObject

@property(nonatomic,assign,readonly) BOOL bluetoothPowerOn;
@property(nonatomic,assign,readonly) LPBluetoothManagerStatus state;
@property(nonatomic,strong,readonly) LPBluetoothModel *model;
@property(nonatomic,weak) id<LPBluetoothManagerDelegate> delegate;

/**
 *  初始化
 *  @param model （蓝牙外设特征）
 */
-(id)initWithModel:(LPBluetoothModel *)model;

//开始扫描
-(void)startScan;
//停止扫描
-(void)stopScan;

/**
 *  建立连接
 *  @param peripheral （外设）
 */
-(void)connectToPeripheral:(LPBluetoothPeripheral *)peripheral;
-(void)disconnect;

/**
 *  写数据
 *  @param data 数据
 */
-(void)writeData:(NSData *)data;

/**
 *  是否可以准备好写数据
 *  @return 是否可以准备好写数据
 */
-(BOOL)isReady;

@end

@protocol LPBluetoothManagerDelegate <NSObject>

@optional

//蓝牙状态改变
-(void)blManager:(LPBluetoothManager *)manager bluetoothChangeState:(NSInteger)state;

-(void)blManager:(LPBluetoothManager *)manager didDiscoverPeripheral:(LPBluetoothPeripheral *)peripheral;
//连接成功
-(void)blManager:(LPBluetoothManager *)manager didConnectPeripheral:(LPBluetoothPeripheral *)peripheral;
//掉线
- (void)blManager:(LPBluetoothManager *)manager didDisconnectPeripheral:(LPBluetoothPeripheral *)peripheral error:(NSError *)error;
//连接外设失败
- (void)blManager:(LPBluetoothManager *)manager didFailToConnectPeripheral:(LPBluetoothPeripheral *)peripheral error:(NSError *)error;
//发送
-(void)blManager:(LPBluetoothManager *)manager didWriteData:(NSData *)data error:(NSError *)error;
//接收
-(void)blManager:(LPBluetoothManager *)manager didReadData:(NSData *)data error:(NSError *)error;

@end
