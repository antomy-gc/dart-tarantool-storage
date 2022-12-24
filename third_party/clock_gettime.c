/*
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 * 1. Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * <COPYRIGHT HOLDER> OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#include "trivia/util.h"

int clock_gettime(uint32_t clock_id, struct timespec *tp)
{
	tp->tv_nsec = 0;
	tp->tv_sec = 0;
	uint64_t tk;
	struct timeval tv;
	switch (clock_id) {
	case CLOCK_REALTIME:
	case CLOCK_MONOTONIC:
		gettimeofday (&tv, 0);
		tp->tv_sec = tv.tv_sec;
		tp->tv_nsec = tv.tv_usec * 1000;
		break;
	case CLOCK_PROCESS_CPUTIME_ID:
	case CLOCK_THREAD_CPUTIME_ID:
		tk = clock();
		tp->tv_sec = tk / CLOCKS_PER_SEC;
		tp->tv_nsec = (tk % CLOCKS_PER_SEC) *
				(1000000000 / CLOCKS_PER_SEC);
		break;
	}
	return 0;
}
