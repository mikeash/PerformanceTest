#import <Foundation/Foundation.h>
#import <mach/mach_time.h>
#import <pthread.h>
#import "perf.h"

#include <algorithm>
#include <vector>

#include <inttypes.h>
#include <stdio.h>


struct RawTestResult {
    uint64_t iterations;
    uint64_t testsPerIteration;
    uint64_t startTime;
    uint64_t endTime;
};

struct TestResult {
    const char *name;
    uint64_t iterations;
    NSTimeInterval total;
    NSTimeInterval each;
};

struct TestInfo {
    const char *name;
    RawTestResult (*fptr)(void);
};

static std::vector<TestInfo> AllTests;
TestInfo EmptyLoopTest;

void Test(void) {
    struct mach_timebase_info tbinfo;
    mach_timebase_info( &tbinfo );
    auto absToNanos = [&](uint64_t abs) { return abs * tbinfo.numer / tbinfo.denom; };
    
    auto overheadResult = EmptyLoopTest.fptr();
    NSTimeInterval totalOverhead = absToNanos(overheadResult.endTime - overheadResult.startTime);
    NSTimeInterval overheadPerIteration = totalOverhead / overheadResult.iterations;
    
    std::vector<TestResult> results;
    
//    size_t i = AllTests.size();
//    while(i --> 0) {
//        auto info = AllTests[i];
    for(auto info : AllTests) {
        @autoreleasepool {
            NSLog(@"Beginning test %s", info.name);
            auto rawResult = info.fptr();
            NSTimeInterval totalTime = absToNanos(rawResult.endTime - rawResult.startTime);
            NSTimeInterval totalMinusOverhead = totalTime - rawResult.iterations * overheadPerIteration;
            NSTimeInterval timePerIteration = totalMinusOverhead / (rawResult.iterations * rawResult.testsPerIteration);
            NSLog(@"Completed test %s in %f seconds total, %fns each", info.name, totalMinusOverhead / NSEC_PER_SEC, timePerIteration);
            
            TestResult result;
            result.name = info.name;
            result.iterations = rawResult.iterations * rawResult.testsPerIteration;
            result.total = totalMinusOverhead / NSEC_PER_SEC;
            result.each = timePerIteration;
            results.push_back(result);
        }
    }
    
    printf("<table><tr><td>Name</td><td>Iterations</td><td>Total time (sec)</td><td>Time per (ns)</td></tr>\n");
    
    std::sort(results.begin(), results.end(), [](TestResult &a, TestResult &b) { return a.each < b.each; });
    for(auto result : results) {
        printf("<tr><td>%s</td><td>%" PRIu64 "</td><td>%.1f</td><td>%.1f</td></tr>\n", result.name, result.iterations, result.total, result.each);
    }
    
    printf("</table>\n");
}

struct RegisterTest {
    RegisterTest(const char *name, RawTestResult (*fptr)(void)) {
        TestInfo info;
        info.name = name;
        info.fptr = fptr;
        
        if(strcmp(name, "Empty loop") == 0) {
            EmptyLoopTest = info;
        } else {
            AllTests.push_back(info);
        }
    }
};

#define CONCAT2(x, y) x ## y
#define CONCAT(x, y) CONCAT2(x, y)

#define DECLARE_TEST(_name, _iterations, _testsPerIteration, _setupCode, _testCode, _cleanupCode) \
    static RegisterTest CONCAT(test, __COUNTER__)(_name, []() -> RawTestResult { \
        RawTestResult info; \
        info.iterations = _iterations; \
        info.testsPerIteration = _testsPerIteration; \
        _setupCode; \
        info.startTime = mach_absolute_time(); \
        for(uint64_t i = 1; i <= _iterations; i++) { \
        /* NOTE: i starts from 1 so it can be used as a divisor for integer division testing, silly I know. */ \
            _testCode; \
        } \
        info.endTime = mach_absolute_time(); \
        _cleanupCode; \
        return info; \
    })

DECLARE_TEST("Empty loop", 1000000000, 1, {}, {}, {});


class StubClass
{
public:
    virtual void stub() { }
};

DECLARE_TEST("C++ virtual method call", 100000000, 10,
             class StubClass *obj = new StubClass,
             obj->stub();
             obj->stub();
             obj->stub();
             obj->stub();
             obj->stub();
             obj->stub();
             obj->stub();
             obj->stub();
             obj->stub();
             obj->stub();,
             delete obj);

@interface DummyClass: NSObject
- (void)dummyMethod;
@end
@implementation DummyClass
- (void)dummyMethod {}
@end

DECLARE_TEST("Objective-C message send", 100000000, 10,
             DummyClass *dummy = [[DummyClass alloc] init],
             [dummy dummyMethod];
             [dummy dummyMethod];
             [dummy dummyMethod];
             [dummy dummyMethod];
             [dummy dummyMethod];
             [dummy dummyMethod];
             [dummy dummyMethod];
             [dummy dummyMethod];
             [dummy dummyMethod];
             [dummy dummyMethod];,
             [dummy release]);

DECLARE_TEST("IMP-cached message send", 100000000, 10,
             DummyClass *dummy = [[DummyClass alloc] init];
             SEL sel = @selector(dummyMethod);
             void (*imp)(id, SEL) = (void (*)(id, SEL))[dummy methodForSelector: sel],
             imp(dummy, sel);
             imp(dummy, sel);
             imp(dummy, sel);
             imp(dummy, sel);
             imp(dummy, sel);
             imp(dummy, sel);
             imp(dummy, sel);
             imp(dummy, sel);
             imp(dummy, sel);
             imp(dummy, sel);,
             [dummy release]);

DECLARE_TEST("NSInvocation message send", 1000000, 10,
             DummyClass *dummy = [[DummyClass alloc] init];
             SEL sel = @selector(dummyMethod);
             NSInvocation *invocation = [NSInvocation invocationWithMethodSignature: [dummy methodSignatureForSelector: sel]];
             [invocation setSelector: sel];
             [invocation setTarget: dummy];,
             [invocation invoke];
             [invocation invoke];
             [invocation invoke];
             [invocation invoke];
             [invocation invoke];
             [invocation invoke];
             [invocation invoke];
             [invocation invoke];
             [invocation invoke];
             [invocation invoke];,
             [dummy release]);

DECLARE_TEST("Integer division", 100000000, 10,
             int x,
             x = 1000000000 / i;
             x = 1000000000 / i;
             x = 1000000000 / i;
             x = 1000000000 / i;
             x = 1000000000 / i;
             x = 1000000000 / i;
             x = 1000000000 / i;
             x = 1000000000 / i;
             x = 1000000000 / i;
             x = 1000000000 / i;,
             );

DECLARE_TEST("Floating-point division", 100000000, 10,
             double x;
             double y = 42.3;,
             x = 100000000.0 / y;
             x = 100000000.0 / y;
             x = 100000000.0 / y;
             x = 100000000.0 / y;
             x = 100000000.0 / y;
             x = 100000000.0 / y;
             x = 100000000.0 / y;
             x = 100000000.0 / y;
             x = 100000000.0 / y;
             x = 100000000.0 / y;,
             );

DECLARE_TEST("Floating-point division with integer conversion", 100000000, 10,
             double x,
             x = 100000000.0 / i;
             x = 100000000.0 / i;
             x = 100000000.0 / i;
             x = 100000000.0 / i;
             x = 100000000.0 / i;
             x = 100000000.0 / i;
             x = 100000000.0 / i;
             x = 100000000.0 / i;
             x = 100000000.0 / i;
             x = 100000000.0 / i;,
             );

extern "C" void objc_release(id);

DECLARE_TEST("Object creation", 1000000, 10, {},
             objc_release([[NSObject alloc] init]);
             objc_release([[NSObject alloc] init]);
             objc_release([[NSObject alloc] init]);
             objc_release([[NSObject alloc] init]);
             objc_release([[NSObject alloc] init]);
             objc_release([[NSObject alloc] init]);
             objc_release([[NSObject alloc] init]);
             objc_release([[NSObject alloc] init]);
             objc_release([[NSObject alloc] init]);
             objc_release([[NSObject alloc] init]);,
             );

DECLARE_TEST("Autorelease pool push/pop", 10000000, 10, {},
             @autoreleasepool {}
             @autoreleasepool {}
             @autoreleasepool {}
             @autoreleasepool {}
             @autoreleasepool {}
             @autoreleasepool {}
             @autoreleasepool {}
             @autoreleasepool {}
             @autoreleasepool {}
             @autoreleasepool {},
             );

DECLARE_TEST("16-byte malloc/free", 10000000, 10, {},
             free(malloc(16));
             free(malloc(16));
             free(malloc(16));
             free(malloc(16));
             free(malloc(16));
             free(malloc(16));
             free(malloc(16));
             free(malloc(16));
             free(malloc(16));
             free(malloc(16));,
             );

DECLARE_TEST("16MB malloc/free", 100000, 10, {},
             free(malloc(1 << 24));
             free(malloc(1 << 24));
             free(malloc(1 << 24));
             free(malloc(1 << 24));
             free(malloc(1 << 24));
             free(malloc(1 << 24));
             free(malloc(1 << 24));
             free(malloc(1 << 24));
             free(malloc(1 << 24));
             free(malloc(1 << 24));,
             );

#define DECLARE_MEMCPY_TEST(humanSize, machineSize, count) \
    DECLARE_TEST(humanSize  " memcpy", count, 10, \
                 char *src = (char *)calloc((machineSize) + 16, 1); \
                 char *dst = (char *)malloc((machineSize) + 16); \
                 char *offsetSrc = src + 16; \
                 char *offsetDst = dst + 16;, \
                 memcpy(offsetDst, offsetSrc, machineSize); \
                 memcpy(offsetDst, offsetSrc, machineSize); \
                 memcpy(offsetDst, offsetSrc, machineSize); \
                 memcpy(offsetDst, offsetSrc, machineSize); \
                 memcpy(offsetDst, offsetSrc, machineSize); \
                 memcpy(offsetDst, offsetSrc, machineSize); \
                 memcpy(offsetDst, offsetSrc, machineSize); \
                 memcpy(offsetDst, offsetSrc, machineSize); \
                 memcpy(offsetDst, offsetSrc, machineSize); \
                 memcpy(offsetDst, offsetSrc, machineSize);, \
                 free(src); \
                 free(dst))

DECLARE_MEMCPY_TEST("16 byte", 16, 100000000);
DECLARE_MEMCPY_TEST("1MB", 1 << 20, 10000);

#define DECLARE_WRITE_FILE_TEST(humanSize, machineSize, count, atomic) \
    DECLARE_TEST(atomic ? "Write " humanSize " file (atomic)" : "Write " humanSize " file", count, 1, \
                 NSData *data = [[NSFileHandle fileHandleForReadingAtPath: @"/dev/random"] readDataOfLength: machineSize], \
                 [data writeToFile: @"/tmp/testrand" atomically: atomic], \
                 [[NSFileManager defaultManager] removeItemAtPath: @"/tmp/testrand" error: NULL])

DECLARE_WRITE_FILE_TEST("16 byte", 16, 10000, NO);
DECLARE_WRITE_FILE_TEST("16 byte", 16, 10000, YES);
DECLARE_WRITE_FILE_TEST("16MB", 1 << 24, 30, NO);
DECLARE_WRITE_FILE_TEST("16MB", 1 << 24, 30, YES);

#define DECLARE_READ_FILE_TEST(humanSize, machineSize, count) \
    DECLARE_TEST("Read " humanSize " file", count, 1, \
                 NSData *data = [[NSFileHandle fileHandleForReadingAtPath: @"/dev/random"] readDataOfLength: machineSize]; \
                 [data writeToFile: @"/tmp/testrand" atomically: NO];, \
                 [[[NSData alloc] initWithContentsOfFile: @"/tmp/testrand"] release], \
                 [[NSFileManager defaultManager] removeItemAtPath: @"/tmp/testrand" error: NULL])

DECLARE_READ_FILE_TEST("16 byte", 16, 100000);
DECLARE_READ_FILE_TEST("16MB", 1 << 24, 100);

static void *stub_pthread( void * )
{
    return NULL;
}

DECLARE_TEST("pthread create/join", 100000, 1, {},
             pthread_t pt;
             pthread_create(&pt, NULL, stub_pthread, NULL);
             pthread_join(pt, NULL);,
             {});

@interface DelayedPerformClass: NSObject @end
@implementation DelayedPerformClass {
    uint64_t _currentIteration;
@public
    uint64_t _iterationLimit;
}

- (void)delayedPerform {
    if(_currentIteration++ < _iterationLimit) {
        [self performSelector: @selector(delayedPerform) withObject: nil afterDelay: 0];
    } else {
        CFRunLoopStop(CFRunLoopGetCurrent());
    }
}

@end

DECLARE_TEST("Zero-zecond delayed perform", 100000, 1,
             DelayedPerformClass *obj = [[DelayedPerformClass alloc] init];
             obj->_iterationLimit = 100000;,
             [obj performSelector: @selector(delayedPerform) withObject: nil afterDelay: 0];
             CFRunLoopRun();
             break;, /* We do our own loop, so break out of the testing loop. Uuuugly. */
             [obj release]);

#if !TARGET_OS_IOS
DECLARE_TEST("NSTask process spawn", 100, 1, {},
             NSTask *task = [[NSTask alloc] init];
             [task setLaunchPath: @"/usr/bin/false"];
             [task launch];
             [task waitUntilExit];
             [task release];,
             );
#endif
