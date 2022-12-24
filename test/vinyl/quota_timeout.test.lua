test_run = require('test_run').new()

test_run:cmd("create server test with script='vinyl/low_quota.lua'")
test_run:cmd("start server test with args='1048576'")
test_run:cmd('switch test')

fiber = require 'fiber'

box.cfg{vinyl_timeout=0.01}
box.error.injection.set('ERRINJ_VY_SCHED_TIMEOUT', 0.01)

--
-- Check that a transaction is aborted on timeout if it exceeds
-- quota and the scheduler doesn't manage to free memory.
--
box.error.injection.set('ERRINJ_VY_RUN_WRITE', true)

s = box.schema.space.create('test', {engine = 'vinyl'})
_ = s:create_index('pk')

pad = string.rep('x', 2 * box.cfg.vinyl_memory / 3)
_ = s:auto_increment{pad}
s:count()
box.stat.vinyl().memory.level0

-- Since the following operation requires more memory than configured
-- and dump is disabled, it should fail with ER_VY_QUOTA_TIMEOUT.
_ = s:auto_increment{pad}
s:count()
box.stat.vinyl().memory.level0

--
-- Check that increasing box.cfg.vinyl_memory wakes up fibers
-- waiting for memory.
--
box.cfg{vinyl_timeout=5}
c = fiber.channel(1)
_ = fiber.create(function() local ok = pcall(s.auto_increment, s, {pad}) c:put(ok) end)
fiber.sleep(0.01)
box.cfg{vinyl_memory = 3 * box.cfg.vinyl_memory / 2}
c:get(1)

box.error.injection.set('ERRINJ_VY_RUN_WRITE', false)
fiber.sleep(0.01) -- wait for scheduler to unthrottle

--
-- Check that there's a warning in the log if a transaction
-- waits for quota for more than too_long_threshold seconds.
--
box.error.injection.set('ERRINJ_VY_RUN_WRITE_DELAY', true)

box.cfg{vinyl_timeout=60}
box.cfg{too_long_threshold=0.01}

pad = string.rep('x', 2 * box.cfg.vinyl_memory / 3)
ch = fiber.channel(1)
f = fiber.create(function() s:auto_increment{pad} s:auto_increment{pad} ch:put(true) end)
fiber.sleep(0.02)

box.error.injection.set('ERRINJ_VY_RUN_WRITE_DELAY', false)
ch:get()

test_run:cmd("push filter '[0-9.]+ sec' to '<sec> sec'")
test_run:grep_log('test', 'waited for .* quota for too long.*')
test_run:cmd("clear filter")

s:truncate()
box.snapshot()

--
-- Check that exceeding quota doesn't hang the scheduler
-- in case there's nothing to dump.
--
-- The following operation should fail instantly irrespective
-- of the value of 'vinyl_timeout' (gh-3291).
--
box.stat.vinyl().memory.level0 == 0
box.cfg{vinyl_timeout = 9000}
pad = string.rep('x', box.cfg.vinyl_memory)
_ = s:auto_increment{pad}

s:drop()
box.snapshot()

--
-- Check that exceeding quota triggers dump of all spaces.
--
s1 = box.schema.space.create('test1', {engine = 'vinyl'})
_ = s1:create_index('pk')
s2 = box.schema.space.create('test2', {engine = 'vinyl'})
_ = s2:create_index('pk')

pad = string.rep('x', 64)
_ = s1:auto_increment{pad}
s1.index.pk:stat().memory.bytes > 0

pad = string.rep('x', box.cfg.vinyl_memory - string.len(pad))
_ = s2:auto_increment{pad}

while s1.index.pk:stat().disk.dump.count == 0 do fiber.sleep(0.01) end
s1.index.pk:stat().memory.bytes == 0

test_run:cmd('switch default')
test_run:cmd("stop server test")
test_run:cmd("cleanup server test")
