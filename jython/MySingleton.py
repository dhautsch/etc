class MySingleton:
    """
    From http://www.exampleprogramming.com/singleton.html

    A singleton is a software design pattern as seen in the
    influential book "Design Patterns: Elements of Reusable
    Object-Oriented Software". A singleton is a class that
    allows only one instance of it to be created. It can be
    useful if you want a common class that can be referenced
    by many different parts of your program, especially if
    your class is a read-only class.

    A possible use, for instance, is a place for storing
    configuration information after reading that info from
    a file. Then the configuration info can be accessed
    repeatedly by different areas.

    The singleton pattern can be implemented in Python
    through the use of an inner class:
    """

    _inner=None
    class inner:
        def __init__(self):
            self.num=None
    def __init__(self):
        if MySingleton._inner is None:
            MySingleton._inner=MySingleton.inner()
    def __getattr__(self, name):
        return getattr(self._inner, name)
    def __setattr__(self, name, value):
        return setattr(self._inner, name, value)

if __name__=="__main__":
    first=MySingleton()
    first.num=5
    print first.num

    second=MySingleton()
    second.num=7
    print second.num
    print first.num
