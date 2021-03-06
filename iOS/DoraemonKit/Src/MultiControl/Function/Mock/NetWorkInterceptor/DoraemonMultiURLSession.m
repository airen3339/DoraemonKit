//
//  DoraemonMultiURLSession.m
//  DoraemonKit
//
//  Created by wzp on 2021/9/23.
//

#import "DoraemonMultiURLSession.h"




@interface DoraemonMultiURLSessionTaskInfo()

@property (atomic, strong, readonly) NSURLSessionDataTask  *task;
@property (atomic, strong, readonly) id<NSURLSessionDataDelegate> delegate;
@property (atomic, strong, readonly) NSThread *     thread;
@property (atomic, strong, readonly) NSArray *      modes;

@property (atomic, strong) NSURLRequest  *request;

@end

//@interface DoraemonMultiURLSessionTaskInfo : <#superclass#>
//
//@end


@implementation DoraemonMultiURLSessionTaskInfo

- (instancetype)initWithTask:(NSURLSessionDataTask *)task delegate:(id <NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes;
{
    NSAssert(task, @"task will  nil");
    NSAssert(delegate, @"delegate will nil");
    NSAssert(modes, @" modes will nil");
    
    self = [super init];
    if (self != nil) {
        self->_task = task;
        self->_delegate = delegate;
        self->_thread = [NSThread currentThread];
        self->_modes = [modes copy];
    }
    
    return self;
}

- (void)performBlock:(dispatch_block_t)block {
    
    NSAssert(self.delegate, @"delegate will nil");
    NSAssert(self.thread, @"thread will nil");
    
    [self performSelector:@selector(performBlockOnClientThread:) onThread:self.thread withObject:[block copy] waitUntilDone:NO modes:self.modes];
}

- (void)performBlockOnClientThread:(dispatch_block_t)block {
    NSAssert([NSThread currentThread] == self.thread, @"self.thread  not [NSThread currentThread]");
    block();
    
}

- (void)invalidate {
    self->_delegate = nil;
    self->_thread = nil;
}

@end


@interface DoraemonMultiURLSession () <NSURLSessionDataDelegate>

@property (atomic, strong, readonly) NSMutableDictionary *taskInfoByTaskID;
@property (atomic, strong, readonly) NSOperationQueue *seesionDelegateQueue;


@end

@implementation DoraemonMultiURLSession

- (instancetype)init {
   return [self initWithConfiguration:nil];
}

- (instancetype)initWithConfiguration:(nullable NSURLSessionConfiguration *)configuration {
    self = [super init];
    if(self != nil) {
        if(!configuration) {
            configuration =  [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        self->_configuration = [configuration copy];
        self->_taskInfoByTaskID =  [[NSMutableDictionary alloc]init];
        self->_seesionDelegateQueue = [[NSOperationQueue alloc]init];
        [self.seesionDelegateQueue setName:NSStringFromClass([DoraemonMultiURLSession class])];
        [self.seesionDelegateQueue setMaxConcurrentOperationCount:1];
        self.seesion.sessionDescription = NSStringFromClass([DoraemonMultiURLSession class]);
        self->_seesion = [NSURLSession sessionWithConfiguration:self->_configuration delegate:self delegateQueue:self->_seesionDelegateQueue];
        
    }
    
    return self;
}

-(NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request delegate:(id <NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes {
    
    NSAssert(request, @"request will nil");
    NSAssert(delegate, @"delegate will nil");
    
    if (modes.count == 0) {
        modes = @[NSDefaultRunLoopMode];
    }
    NSURLSessionDataTask * task = [self.seesion dataTaskWithRequest:request];
    NSAssert(task, @"task create will nil");
    
    DoraemonMultiURLSessionTaskInfo * taskInfo = [[DoraemonMultiURLSessionTaskInfo alloc]initWithTask:task delegate:delegate modes:modes];
    taskInfo.request = request;
    
    @synchronized (self) {
        self.taskInfoByTaskID[@(task.taskIdentifier)] = taskInfo;
    }

    return task;
    
}

- (DoraemonMultiURLSessionTaskInfo *)taskInfoForTask:(NSURLSessionTask *)task {
    DoraemonMultiURLSessionTaskInfo *taskInfo;
    
    NSAssert(task, @"taskInfoForTask task will nil");
    
    @synchronized (self) {
        taskInfo = self.taskInfoByTaskID[@(task.taskIdentifier)];
        NSAssert(taskInfo, @"taskInfoForTask taskInfo will nil");
    }
    return taskInfo;
}

#pragma mark -- NSURLSessionDataDelegate

/*
 *  ??????????????????????????????????????????
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)newRequest completionHandler:(void (^)(NSURLRequest *))completionHandler {
    
    DoraemonMultiURLSessionTaskInfo *taskInfo = [self taskInfoForTask:task];
    
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task willPerformHTTPRedirection:response newRequest:newRequest completionHandler:completionHandler];
        }];
    }else {
        completionHandler(newRequest);
    }
}

/*
 *  ?????? ?????????????????????????????? -- ???????????????
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
    DoraemonMultiURLSessionTaskInfo *taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
        }];
    }else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
    
    
}

/* ??????>>????????????????????????--??????????????????????????????
 ?????????????????????????????????????????????????????????????????????????????????
 ????????????????????????????????????????????????
 1???????????????uploadTaskWithStreamedRequest????????????????????????????????????????????????
 2??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
 ??????????????????????????????URL???NSData?????????????????????????????????????????????????????????
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler{
    DoraemonMultiURLSessionTaskInfo *taskInfo;
    
    taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:needNewBodyStream:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task needNewBodyStream:completionHandler];
        }];
    } else {
        completionHandler(nil);
    }
}


/*
 *  ??????>>????????????
 *  ?????????????????????????????????????????????????????????
 */

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend{
    DoraemonMultiURLSessionTaskInfo *taskInfo;
    
    taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
        }];
    }
}

/*
 *  ??????>>????????????
 *  ?????????????????????????????????
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    DoraemonMultiURLSessionTaskInfo *taskInfo;
    
    taskInfo = [self taskInfoForTask:task];
    @synchronized (self) {
        [self.taskInfoByTaskID removeObjectForKey:@(taskInfo.task.taskIdentifier)];
    }
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task didCompleteWithError:error];
            [taskInfo invalidate];
        }];
    } else {
        [taskInfo invalidate];
    }
}

/*
 * ??????>>????????????????????????
 * ??????>>???????????????
 * ????????????????????????????????????????????????(??????????????????????????????????????????????????????)
 */

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler{
    DoraemonMultiURLSessionTaskInfo *taskInfo;
    
    taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
        }];
    } else {
        completionHandler(NSURLSessionResponseAllow);
    }
}

/*
 * ??????>>????????????????????????????????????
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask{
    DoraemonMultiURLSessionTaskInfo *taskInfo;
    
    taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:didBecomeDownloadTask:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask didBecomeDownloadTask:downloadTask];
        }];
    }
}

/*
 * ??????>>???????????????????????????
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data{
    DoraemonMultiURLSessionTaskInfo *taskInfo;
    
    taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask didReceiveData:data];
        }];
    }
}

/*
 * ??????>>?????????Response?????????Cache???
 * ??????????????????????????????????????????
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler{
    DoraemonMultiURLSessionTaskInfo *taskInfo;
    
    taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:willCacheResponse:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
        }];
    } else {
        completionHandler(proposedResponse);
    }
}





@end
