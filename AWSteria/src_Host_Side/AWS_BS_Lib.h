#pragma once

extern
void AWS_BS_Lib_init (void);

extern
void AWS_BS_Lib_shutdown (void);

extern
void open_dma_read  (uint8_t * read_buffer, size_t buffer_size);

extern
void open_dma_write ();

extern
void close_dma_read  (void);

extern
void close_dma_write (void);

extern
int dma_burst_read (uint8_t *buffer, size_t size, uint64_t address, int channel);

extern
int dma_burst_write (uint8_t *buffer, size_t size, uint64_t address, int channel);

extern
int ocl_peek (uint32_t ocl_addr, uint32_t *p_ocl_data);

extern
int ocl_poke (uint32_t ocl_addr, uint32_t ocl_data);
