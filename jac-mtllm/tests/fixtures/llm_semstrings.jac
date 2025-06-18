import from mtllm.llms { FakeLLM }
glob llm = FakeLLM(
    print_prompt=True,
    responses={
        "\n[System Prompt]\nThis is an operation you must perform and return the output values. Neither, the methodology, extra sentences nor the code are not needed.\nInput/Type formatting: Explanation of the Input (variable_name) (type) = value\n\n[Output_Information]\n(int)\n\n[Action]\nGenerates a specific number that is 120597 and returns it. (generate_specific_number)\nGenerate and return the output result(s) only, adhering to the provided Type in the following format\n\n[Output] <result>\n":
        "[Output] 120597",

        "\n[System Prompt]\nThis is an operation you must perform and return the output values. Neither, the methodology, extra sentences nor the code are not needed.\nInput/Type formatting: Explanation of the Input (variable_name) (type) = value\n\n[Output_Information]\n(str)\n\n[Action]\nGenerates and returns password that:\n    - contain at least 8 characters\n    - contain at least one uppercase letter\n    - contain at least one lowercase letter\n    - contain at least one digit\n    - contain at least one special character\n (generate_password)\nGenerate and return the output result(s) only, adhering to the provided Type in the following format\n\n[Output] <result>\n":
        "[Output] R8@jL3pQ",
    },
);


def generate_password() -> str by llm();
sem generate_password = """\
Generates and returns password that:
    - contain at least 8 characters
    - contain at least one uppercase letter
    - contain at least one lowercase letter
    - contain at least one digit
    - contain at least one special character
""";


# This will only retuen 120597 that is defined in the sem string, returning any other number means.
#   1. The semstring is not working correctly.
#   2. The llm is not working correctly.
#       - Should use a better llm that can perform well.
#       - Should use a lower temperature to ensure the output is deterministic.
def generate_specific_number() -> int by llm();

sem generate_specific_number = "Generates a specific number that is 120597 and returns it.";


with entry {
    specific_number = generate_specific_number();
    print('Specific number generated:', specific_number);

    password = generate_password();
    print('Generated password:', password);
}
