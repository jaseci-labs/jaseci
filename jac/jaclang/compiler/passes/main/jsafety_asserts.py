from typing import Any, Callable
from jaclang.settings import settings


class JSafetyAsserts:
    """
    This class is responsible for handling safety asserts in the Jac language.
    It ensures that the asserts are properly handled during the compilation process.
    """

    @classmethod
    def _assert_condition(cls, condition: Callable[[], bool], msg: str) -> bool:
        """Private helper method to handle assertion logic."""
        if settings.safety_assert:
            try:
                assert condition()
                return True
            except AssertionError:
                return False
        else:
            assert condition(), msg
            return True

    @classmethod
    def assert_isinstance(cls, obj, expected_type, custom_msg: str = "") -> bool:
        """Helper method for isinstance assertions."""
        msg = custom_msg or f"Expected {obj} to be of type {expected_type}, but got {type(obj)} instead."
        return cls._assert_condition(lambda: isinstance(obj, expected_type), msg)

    @classmethod
    def assert_not_none(cls, obj, custom_msg: str = "") -> bool:
        """Helper method for not None assertions."""
        msg = custom_msg or "Expected object to not be None."
        return cls._assert_condition(lambda: obj is not None, msg)

    @classmethod
    def assert_is_none(cls, obj, custom_msg: str = "") -> bool:
        """Helper method for is None assertions."""
        msg = custom_msg or "Expected object to be None."
        return cls._assert_condition(lambda: obj is None, msg)
