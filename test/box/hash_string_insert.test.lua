-------------------------------------------------------------------------------
-- String hash inset fields tests
-------------------------------------------------------------------------------
hash = box.schema.space.create('tweedledum')
tmp = hash:create_index('primary', { type = 'hash', parts = {1, 'string'}, unique = true })

-- Insert valid fields
hash:insert{'key 0', 'value1 v1.0', 'value2 v1.0'}
hash:insert{'key 1', 'value1 v1.0', 'value2 v1.0'}
hash:insert{'key 2', 'value1 v1.0', 'value2 v1.0'}
hash:insert{'key 3', 'value1 v1.0', 'value2 v1.0'}

hash:drop()
