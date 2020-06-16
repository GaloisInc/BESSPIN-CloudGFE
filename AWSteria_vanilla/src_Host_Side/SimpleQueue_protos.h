// This file is generated automatically from the file 'SimpleQueue.c'
//     and contains 'extern' function prototype declarations for its functions.
// In any C source file using these functions, add:
//     #include "SimpleQueue_protos.h"
// You may also want to create/maintain a file 'SimpleQueue.h'
//     containing #defines and type declarations.
// ****************************************************************

#pragma once

extern
SimpleQueue *SimpleQueueInit (void);

extern
int SimpleQueuePut (SimpleQueue *queue, uint64_t data);

extern
int SimpleQueueGet (SimpleQueue *queue, uint64_t *p_data);

extern
int SimpleQueueFirst (SimpleQueue *queue, uint64_t *p_data);

extern
bool SimpleQueueFull (SimpleQueue *queue);

extern
bool SimpleQueueEmpty (SimpleQueue *queue);

extern
int SimpleQueueOccupancy (SimpleQueue *queue);
