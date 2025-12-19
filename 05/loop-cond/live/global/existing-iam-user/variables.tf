# variable "names" {
#   description = "A list of names"
#   type        = list(string)
#   default     = ["neo", "trinity", "morpheus"]
# }

# output "upper_names" {
#   value = [for name in var.names : upper(name)]  # ["NEO", "TRINITY", "MORPHEUS"]
# }

# output "short_upper_names" {
#   value = [for name in var.names : upper(name) if length(name) < 5]  # ["NEO"]
# }

##### for expression - map input #####
variable "hero_thousand_faces" {
  description = "map"
  type        = map(string)
  default     = {
    neo      = "hero"
    trinity  = "love interest"
    morpheus = "mentor"
  }
}

output "bios" {
  value = [for name, role in var.hero_thousand_faces : "${name} is the ${role}"]
}       # ["neo is the hero", "trinity is the love interest", "morpheus is the mentor"]

output "upper_roles" {
  value = {for name, role in var.hero_thousand_faces : upper(name) => upper(role)}
}       # {"NEO" = "HERO", "trinity" = "LOVE INTEREST", "MORPHEUS" = "MENTOR"}