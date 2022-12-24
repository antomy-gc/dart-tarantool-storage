netbox = require('net.box')
test_run = require('test_run').new()
remote = test_run:get_cfg('remote') == 'true'

nb = nil
if remote then \
    box.schema.user.grant('guest','super') \
    nb = netbox.connect(box.cfg.listen) \
else \
    nb = netbox.self \
end

--
-- netbox:self and netbox:connect should work interchangeably
--
type(nb:eval('return box.tuple.new{1}')) -- table
type(nb:eval('return box.error.new(1, "test error")')) -- string
type(nb:eval('return box.NULL')) -- cdata

if remote then \
    box.schema.user.revoke('guest', 'super') \
    nb:close() \
end
