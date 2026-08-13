## Purpose

Provide deterministic, in-process suppression of duplicate asynchronous work while preserving independent execution for distinct event keys.

## ADDED Requirements

### Requirement: Key-scoped execution
The guard SHALL coordinate actions by key within a single guard instance, using the key type's equality and hash-code semantics. Keys that are not equal SHALL have independent execution state.

#### Scenario: First occurrence executes
- **WHEN** a key with no active execution or cooldown is submitted with an action
- **THEN** the guard invokes the action exactly once

#### Scenario: Different keys execute independently
- **WHEN** an action is running for one key and another key is submitted
- **THEN** the guard invokes the second key's action without waiting for the first action

#### Scenario: Guard instances do not share state
- **WHEN** equal keys are submitted to two different guard instances
- **THEN** each guard evaluates and executes its key independently

### Requirement: In-flight duplicate suppression
The guard SHALL drop a submission whose key already has an action in progress and SHALL identify the reason as `alreadyRunning`.

#### Scenario: Duplicate arrives while action is pending
- **WHEN** a key is submitted while an earlier action for the same key has not completed
- **THEN** the duplicate action is not invoked and the submission returns a dropped result with reason `alreadyRunning`

#### Scenario: Reentrant action submits the same key
- **WHEN** a running action submits its own key to the same guard before completing
- **THEN** the nested action is not invoked and the nested submission returns a dropped result with reason `alreadyRunning`

### Requirement: Informative execution result
The guard SHALL return an executed result containing the action's exact value when an action completes successfully, and a dropped result containing a drop reason when an action is suppressed.

#### Scenario: Successful asynchronous action
- **WHEN** an asynchronous action completes successfully with a value
- **THEN** the submission returns an executed result containing that value

#### Scenario: Successful synchronous action
- **WHEN** a synchronous action returns a value
- **THEN** the submission returns an executed result containing that value

#### Scenario: Null is a valid action value
- **WHEN** an action completes successfully with a null value
- **THEN** the submission returns an executed result containing null rather than a dropped result

### Requirement: Success-based cooldown
The guard SHALL begin the configured cooldown when an action completes successfully. During a positive cooldown, the guard SHALL drop the same key with reason `cooldown`; after the cooldown expires, it SHALL allow that key to execute again.

#### Scenario: Duplicate arrives during cooldown
- **WHEN** an action completes successfully and the same key is submitted before its positive cooldown expires
- **THEN** the duplicate action is not invoked and the submission returns a dropped result with reason `cooldown`

#### Scenario: Key is submitted after cooldown
- **WHEN** the configured cooldown has expired for a key and that key is submitted again
- **THEN** the guard invokes the new action

#### Scenario: Cooldown starts after completion
- **WHEN** an action runs longer than the configured cooldown duration
- **THEN** the full cooldown still applies beginning at the action's successful completion

#### Scenario: Zero cooldown
- **WHEN** the configured cooldown is zero and an action completes successfully
- **THEN** the same key is immediately eligible for another execution

### Requirement: Failure propagation and recovery
The guard MUST propagate synchronous and asynchronous action failures to the caller, MUST release the running key, and MUST NOT start a cooldown for the failed action.

#### Scenario: Asynchronous action fails
- **WHEN** a running asynchronous action completes with an error
- **THEN** the submission completes with that error and the same key is immediately eligible for another execution

#### Scenario: Synchronous action throws
- **WHEN** invoking a synchronous action throws an error
- **THEN** the submission completes with that error and the same key is immediately eligible for another execution

### Requirement: Cooldown validation
The guard MUST reject a negative cooldown duration when it is constructed.

#### Scenario: Negative cooldown is configured
- **WHEN** a caller constructs a guard with a cooldown less than zero
- **THEN** construction fails with an argument error

### Requirement: Expired state cleanup
The guard MUST remove per-key state after an action fails, after a zero-cooldown success, or after a positive cooldown expires. Cleanup from an older execution MUST NOT remove state belonging to a newer execution of the same key.

#### Scenario: Positive cooldown expires
- **WHEN** a key's positive cooldown reaches its expiration
- **THEN** the guard no longer retains the expired state for that key

#### Scenario: Older cleanup overlaps a newer execution
- **WHEN** stale cleanup associated with an older execution runs after a newer execution has registered the same key
- **THEN** the newer execution remains registered and protected from duplicates
