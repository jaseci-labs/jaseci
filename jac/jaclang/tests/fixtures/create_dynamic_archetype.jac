import from jaclang.runtimelib.machine { JacMachine } 
# Dynamically create a node archetype
 glob source_code = """
node dynamic_node {
has value:int;
can print_value with entry {
print("Dynamic Node Value:", f'{self.value}');
}
}
""";

# Create a new walker archetype dynamically
 glob walker_code = """
walker dynamic_walker {
can visit_nodes with entry {
visit [-->];
}
}
""";


with entry {
    node_arch = JacMachine.create_archetype_from_source(source_code);
    walker_arch = JacMachine.create_archetype_from_source(walker_code);
    node_obj = JacMachine.spawn_node(
        'dynamic_node', {'value' : 99 }, node_arch.__name__
    );
    walker_obj = JacMachine.spawn_walker(
        'dynamic_walker', module_name=walker_arch.__name__
    );
    node_obj spawn walker_obj;
}
