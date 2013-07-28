$nodes = loadyaml('/etc/puppet/nodes.yaml')
require tools
require python::defaultpackages
require hadoop
