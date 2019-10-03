class MyTreeFactory:
    """
    From http://www.exampleprogramming.com/factory.html

    A factory is a software design pattern as seen in the
    influential book "Design Patterns: Elements of Reusable
    Object-Oriented Software". It's generally good programming
    practice to abstract your code as much as possible to limit
    what needs to be updated, when a change is required.
    """

    class Oak:
        def get_message(self):
            return "This is an Oak Tree"
    class Pine:
        def get_message(self):
            return "This is a Pine Tree"
    class Maple:
        def get_message(self):
            return "This is a Maple Tree"
    @staticmethod
    def create_tree(tree):
        if tree=="Oak":
            return TreeFactory.Oak()
        elif tree=="Pine":
            return TreeFactory.Pine()
        elif tree=="Maple":
            return TreeFactory.Maple()

if __name__=="__main__":
    def print_trees(tree_list):
        for current in tree_list:
            tree=TreeFactory.create_tree(current)
            print tree.get_message()

    tree_list=["Oak","Pine","Maple"]
    print_trees(tree_list)
