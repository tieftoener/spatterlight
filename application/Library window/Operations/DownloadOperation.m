//
//  DownloadOperation.m
//
//  Created by Administrator on 2021-10-21.
//

#import "DownloadOperation.h"

typedef NS_ENUM(NSUInteger, OperationState) {
    kReady,
    kExecuting,
    kFinished
};

@interface DownloadOperation ()

@property NSURLSessionDataTask *task;

@property (atomic) OperationState state;

@end


@implementation DownloadOperation


// default state is ready (when the operation is created)

@synthesize state = _state;

- (void)setState:(OperationState)state {
    @synchronized(self) {
        if (_state != state) {
            [self willChangeValueForKey:@"isExecuting"];
            [self willChangeValueForKey:@"isFinished"];
            _state = state;
            [self didChangeValueForKey: @"isExecuting"];
            [self didChangeValueForKey: @"isFinished"];
        }
    }
}

- (OperationState)state {
    @synchronized(self) {
        return _state;
    }
}

- (BOOL)isReady { return (self.state == kReady); }
- (BOOL)isExecuting { return (self.state == kExecuting); }
- (BOOL)isFinished { return (self.state == kFinished); }

- (BOOL)isAsynchronous {
    return YES;
}

+ (NSSet<NSString *> *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
    if ([@[@"isReady", @"isFinished", @"isExecuting"] containsObject:key]) {
        return [keyPaths setByAddingObject:@"state"];
    }
    return keyPaths;
}

- (instancetype)initWithSession:(NSURLSession *)session dataTaskURL:(NSURL *)dataTaskURL completionHandler:(nullable void (^)(NSData * _Nullable,  NSURLResponse * _Nullable,  NSError * _Nullable))completionHandler {

    self = [super init];

    if (self) {
        _state = kReady;
        DownloadOperation __weak *weakSelf = self;
        // use weak self to prevent retain cycle
        _task = [session dataTaskWithURL:dataTaskURL
                                            completionHandler:^(NSData * _Nullable localData, NSURLResponse * _Nullable response, NSError * _Nullable error) {

            DownloadOperation *strongSelf = weakSelf;

            /*
             don't run completionHandler if cancelled
             */
            if (strongSelf && strongSelf.cancelled) {
                strongSelf.state = kFinished;
                return;
            }

            /*
             if there is a custom completionHandler defined,
             pass the result gotten in downloadTask's completionHandler to the
             custom completionHandler
             */
            if (completionHandler) {
                completionHandler(localData, response, error);
            }

            /*
             set the operation state to finished once
             the download task is completed or have error
             */
            if (strongSelf)
                strongSelf.state = kFinished;
        }];
    }

    return self;
}

- (void)start {
    /*
     if the operation or queue got cancelled even
     before the operation has started, set the
     operation state to finished and return
     */
    if (self.cancelled) {
        self.state = kFinished;
        return;
    }

    // set the state to executing
    self.state = kExecuting;

//    NSLog(@"downloading %@", self.task.originalRequest.URL.absoluteString);

    // start the downloading
    [self.task resume];
}

-(void)cancel {
    BOOL wasExecuting = (self.state == kExecuting);
    [super cancel];

    // cancel the downloading
    if (wasExecuting)
        [self.task cancel];
}

@end
