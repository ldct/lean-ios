import ExampleBase

@[export addOne]
def addOne (n : UInt32) : UInt32 :=
  ExampleBase.increment n
