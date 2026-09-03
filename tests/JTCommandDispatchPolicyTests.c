#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "JTCommandDispatchPolicy.h"

static int assertions;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

int main(void) {
    JTCommandDispatchPolicy policy = JT_COMMAND_DISPATCH_POLICY_INITIALIZER;

    Assert(JTCommandDispatchPolicyPending(&policy) == 0,
           "a fresh queue is empty");
    for (int index = 0; index < JT_COMMAND_DISPATCH_MAX_PENDING; index++) {
        Assert(JTCommandDispatchPolicyTryEnqueue(&policy),
               "work is accepted up to the queue bound");
    }
    Assert(!JTCommandDispatchPolicyTryEnqueue(&policy),
           "work beyond the queue bound is rejected");
    Assert(JTCommandDispatchPolicyPending(&policy) ==
               JT_COMMAND_DISPATCH_MAX_PENDING,
           "rejected work consumes no slot");

    Assert(JTCommandDispatchPolicyBeginExecution(&policy, 0.10),
           "fresh work executes");
    Assert(JTCommandDispatchPolicyPending(&policy) ==
               JT_COMMAND_DISPATCH_MAX_PENDING - 1,
           "execution releases its queue slot");
    Assert(!JTCommandDispatchPolicyBeginExecution(&policy, 0.50),
           "stale work is discarded");
    Assert(JTCommandDispatchPolicyPending(&policy) ==
               JT_COMMAND_DISPATCH_MAX_PENDING - 2,
           "discarding stale work also releases its slot");
    Assert(!JTCommandDispatchPolicyBeginExecution(&policy, NAN),
           "invalid age is fail-closed");
    Assert(JTCommandDispatchPolicyTryEnqueue(&policy),
           "released capacity can accept new work");

    while (JTCommandDispatchPolicyPending(&policy) > 0) {
        JTCommandDispatchPolicyBeginExecution(&policy, 0.0);
    }
    Assert(!JTCommandDispatchPolicyBeginExecution(&policy, 0.0),
           "execution without an accepted slot is harmless");
    Assert(JTCommandDispatchPolicyPending(NULL) == 0,
           "a null queue reports empty");
    Assert(!JTCommandDispatchPolicyTryEnqueue(NULL),
           "a null queue rejects work");

    printf("command dispatch policy tests passed (%d assertions)\n",
           assertions);
    return 0;
}
