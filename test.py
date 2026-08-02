class Person:
    def __init__(self,name,age):
        self.name = name
        self.age = age

    def getName(self):
        return self.name

person1 = Person("tadiwa", 18)
print(person1.getName())
