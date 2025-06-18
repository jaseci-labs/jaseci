from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _
from mtllm.llms import FakeLLM
llm = FakeLLM(default='[Output] R8@jL3pQ')

def generate_password() -> None:
    return _.with_llm(file_loc=__file__, model=llm, model_params={}, scope='semstrings(Module).generate_password(Ability)', incl_info=[], excl_info=[], inputs=[], outputs=('', 'str'), action='Generates and returns password that:\n- contain at least 8 characters\n- contain at least one uppercase letter\n- contain at least one lowercase letter\n- contain at least one digit\n- contain at least one special character\n (generate_password)\n', _globals=globals(), _locals=locals())
password = generate_password()
print('Generated password:', password)