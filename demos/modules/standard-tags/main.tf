###############################################################################
# The precon's tagging standard, in one place
#
# Every demo stack calls this module, so a value changed here reaches every
# stack on its next apply. azurerm has no provider-level default tags, so the
# map still has to be passed to each resource — this module makes sure it is
# the same map everywhere.
#
# Each tag answers one of the three jobs on the tagging slide:
#   cost        Workload, CostCenter
#   automation  Environment, Demo, ManagedBy
#   ownership   Owner
###############################################################################

locals {
  tags = merge(var.extra_tags, {
    Workload    = var.workload
    Environment = var.environment
    Demo        = var.demo
    CostCenter  = var.cost_center
    Owner       = var.owner
    ManagedBy   = "Terraform"
  })
}
