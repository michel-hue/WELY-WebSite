import { Module } from '@nestjs/common';
import { ExpiryJob } from './expiry.job.js';

@Module({
  providers: [ExpiryJob],
  exports: [ExpiryJob],
})
export class JobsModule {}
