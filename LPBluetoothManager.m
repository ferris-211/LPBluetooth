//
//  LPBluetoothManager.m
//  LPBluetoothDemo
//
//  Created by Ferris on 2019/3/25.
//  Copyright © 2019年 LP. All rights reserved.
//

#import "LPBluetoothManager.h"

@interface LPBluetoothManager()<CBCentralManagerDelegate,CBPeripheralDelegate>

@property(nonatomic,assign) BOOL bluetoothPowerOn;
@property(nonatomic,assign) LPBluetoothManagerStatus state;

@property(nonatomic,strong) LPBluetoothModel *model;
@property(nonatomic,strong) LPBluetoothPeripheral *connectPeripheral;

@property (nonatomic,assign) BOOL cbReady;
@property (nonatomic,strong) CBCentralManager *cbCM;
@property(nonatomic,strong) CBPeripheral *cbPeripheral;
@property (nonatomic,strong) CBCharacteristic *writeCharacteristic;
@property (nonatomic,strong) CBCharacteristic *readCharacteristic;

-(void)writeCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID data:(NSData *)data;
-(void)setNotificationForCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID enable:(BOOL)enable;

@end

@implementation LPBluetoothManager

/**
 *  初始化
 *  @param model （蓝牙外设特征）
 */
-(id)initWithModel:(LPBluetoothModel *)model
{
    self = [self init];
    if (self) {
        self.model = model;
        
        self.cbCM = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
        self.cbReady = NO;
        self.bluetoothPowerOn = NO;
        self.state = LPBluetoothManagerWait;
    }
    return self;
}

//开始扫描
-(void)startScan
{
    if(self.bluetoothPowerOn)
    {
        if(!self.cbReady)
        {
            if (self.model.sUUID && ![self.model.sUUID isEqualToString:@""]) {
                CBUUID *uid = [CBUUID UUIDWithString:self.model.sUUID];
                [self.cbCM scanForPeripheralsWithServices:@[uid] options:nil];
            }
            else
            {
                [self.cbCM scanForPeripheralsWithServices:nil options:nil];
            }
            
            
            self.state = LPBluetoothManagerScanning;
        }
    }
}

//停止扫描
-(void)stopScan
{
    [self.cbCM stopScan];
    self.state = LPBluetoothManagerWait;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startScan) object:nil];
}

/**
 *  建立连接
 *  @param peripheral （外设）
 */
-(void)connectToPeripheral:(LPBluetoothPeripheral *)peripheral
{
    if (!self.cbReady) {
        self.connectPeripheral = peripheral;
        self.state = LPBluetoothManagerConnecting;
        [self.cbCM connectPeripheral:peripheral.peripheral options:nil];
        
    }
}

-(void)disconnect
{
    if (self.cbReady && self.connectPeripheral) {
        [self.cbCM cancelPeripheralConnection:self.connectPeripheral.peripheral];
        self.connectPeripheral = nil;
        self.state = LPBluetoothManagerWait;
    }
}

/**
 *  写数据
 *  @param data 数据
 */
-(void)writeData:(NSData *)data
{
    if (self.cbReady && self.writeCharacteristic) {
        [self.cbPeripheral writeValue:data forCharacteristic:self.writeCharacteristic type:CBCharacteristicWriteWithResponse];
    }
}

/**
 *  是否可以准备好写数据
 *  @return 是否可以准备好写数据
 */
-(BOOL)isReady
{
    return self.cbReady;
}

//==================
#pragma mark -CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBManagerStatePoweredOff:
            self.cbReady = NO;
            self.bluetoothPowerOn = NO;
            //对外抛出断开连接的通知
            if (self.delegate && [self.delegate respondsToSelector:@selector(blManager:didDisconnectPeripheral:error:)]) {
                [self.delegate blManager:self didDisconnectPeripheral:self.connectPeripheral error:nil];
            }
            break;
        case CBManagerStatePoweredOn:
            self.bluetoothPowerOn = YES;
            break;
        case CBManagerStateResetting:
            break;
        case CBManagerStateUnauthorized:
            break;
        case CBManagerStateUnknown:
            break;
        case CBManagerStateUnsupported:
            break;
        default:
            break;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(blManager:bluetoothChangeState:)]) {
        [self.delegate blManager:self bluetoothChangeState:central.state];
    }
}


//已发现从机设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Did discover peripheral. peripheral: %@ rssi: %@, UUID: %@ advertisementData: %@ ", peripheral, RSSI, peripheral.identifier, advertisementData);
    if (self.model.name && ![self.model.name isEqualToString:@""]) {
        if (![peripheral.name isEqualToString:self.model.name]) {
            return;
        }
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(blManager:didDiscoverPeripheral:)]) {
        LPBluetoothPeripheral *p = [[LPBluetoothPeripheral alloc]init];
        p.peripheral = peripheral;
        p.advertisementData = advertisementData;
        p.RSSI = RSSI;
        [self.delegate blManager:self didDiscoverPeripheral:p];
    }
    
}


//已链接到从机
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    
    //取消重连
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startScan) object:nil];
    //发现services
    //设置peripheral的delegate未self非常重要，否则，didDiscoverServices无法回调
    peripheral.delegate = self;
    peripheral.delegate = self;
    self.cbPeripheral = peripheral;
    self.readCharacteristic = nil;
    self.writeCharacteristic = nil;
    if (self.model.sUUID && ![self.model.sUUID isEqualToString:@""]) {
        [peripheral discoverServices:@[[CBUUID UUIDWithString:self.model.sUUID]]];
    }
    else
    {
        [peripheral discoverServices:nil];
    }
}

//连接外设失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;
{
    self.cbReady = NO;
    peripheral.delegate = nil;
    self.cbPeripheral = nil;
    self.state = LPBluetoothManagerWait;
    //对外抛出断开连接的通知
    if (self.delegate && [self.delegate respondsToSelector:@selector(blManager:didFailToConnectPeripheral:error:)]) {
        [self.delegate blManager:self didFailToConnectPeripheral:self.connectPeripheral error:nil];
    }
}

//已断开从机的链接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    //Do something when a peripheral is disconnected.
    self.cbReady = NO;
    peripheral.delegate = nil;
    self.cbPeripheral = nil;
    self.state = LPBluetoothManagerWait;
    //对外抛出断开连接的通知
    if (self.delegate && [self.delegate respondsToSelector:@selector(blManager:didDisconnectPeripheral:error:)]) {
        [self.delegate blManager:self didDisconnectPeripheral:self.connectPeripheral error:nil];
    }
}

//delegate of CBPeripheral
//已搜索到services
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    for (CBService *s in peripheral.services) {
        [peripheral discoverCharacteristics:nil forService:s];
    }
}

#pragma mark -CBPeripheralDelegate

//已搜索到Characteristics
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    for (CBCharacteristic * characteristic in service.characteristics)
    {
        if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:self.model.cwUUID]])
        {
            self.writeCharacteristic = characteristic;
        }
        else if( [characteristic.UUID isEqual:[CBUUID UUIDWithString:self.model.crUUID]])
        {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            self.readCharacteristic = characteristic;
        }
    }
    if (self.writeCharacteristic && self.readCharacteristic) {
        self.cbReady = YES;
        self.state = LPBluetoothManagerConnected;
        //回调
        if (self.delegate && [self.delegate respondsToSelector:@selector(blManager:didConnectPeripheral:)]) {
            [self.delegate blManager:self didConnectPeripheral:self.connectPeripheral];
        }
    }
}


//已读到char
-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (characteristic == self.readCharacteristic) {
        NSData *data = characteristic.value;
        if (self.delegate && [self.delegate respondsToSelector:@selector(blManager:didReadData:error:)]) {
            [self.delegate blManager:self didReadData:data error:error];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error

{
    if (characteristic == self.writeCharacteristic) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(blManager:didWriteData:error:)]) {
            [self.delegate blManager:self didWriteData:characteristic.value error:error];
        }
    }
}


#pragma mark private

-(id)init
{
    self = [super init];
    if (self) {
        self.cbCM = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        self.cbReady = NO;
        self.bluetoothPowerOn = NO;
    }
    return self;
}

-(void)writeCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID data:(NSData *)data
{
    // Sends data to BLE peripheral to process HID and send EHIF command to PC
    for ( CBService *service in peripheral.services ) {
        //检查服务号
        if (self.model.sUUID) {
            if (![service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
                continue;
            }
        }
        //遍历
        for ( CBCharacteristic *characteristic in service.characteristics ) {
            if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]]) {
                [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
            }
        }
    }
}

-(void)setNotificationForCharacteristic:(CBPeripheral *)peripheral sUUID:(NSString *)sUUID cUUID:(NSString *)cUUID enable:(BOOL)enable
{
    for ( CBService *service in peripheral.services ) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            for (CBCharacteristic *characteristic in service.characteristics ) {
                if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:cUUID]])
                {
                    /* Everything is found, set notification ! */
                    [peripheral setNotifyValue:enable forCharacteristic:characteristic];
                }
            }
        }
    }
}

@end

@implementation LPBluetoothPeripheral

@end
