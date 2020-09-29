package main


deny[msg] {
  regions := ["ap-northeast-1", "ap-northeast-2"]
  input.platform.aws.region != regions[_]
  msg := sprintf("👻 %s is haunted. 👻", [input.platform.aws.region])
}
