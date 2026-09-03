#ifndef JTCommandDispatchPolicy_h
#define JTCommandDispatchPolicy_h

#include <stdbool.h>
#include <stdatomic.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Bounds discrete gesture work waiting for AppKit. A gesture action is useful
 * only while it is fresh; replaying a backlog later is both surprising and
 * dangerous for commands such as Close, Paste, or tab navigation.
 */
typedef struct {
    atomic_int pendingCount;
} JTCommandDispatchPolicy;

#define JT_COMMAND_DISPATCH_POLICY_INITIALIZER { ATOMIC_VAR_INIT(0) }
#define JT_COMMAND_DISPATCH_MAX_PENDING 4
#define JT_COMMAND_DISPATCH_MAX_AGE_SECONDS 0.35

bool JTCommandDispatchPolicyTryEnqueue(JTCommandDispatchPolicy *policy);

/* Releases one accepted queue slot and reports whether it is still fresh. */
bool JTCommandDispatchPolicyBeginExecution(JTCommandDispatchPolicy *policy,
                                           double ageSeconds);

int JTCommandDispatchPolicyPending(const JTCommandDispatchPolicy *policy);

#ifdef __cplusplus
}
#endif

#endif /* JTCommandDispatchPolicy_h */
