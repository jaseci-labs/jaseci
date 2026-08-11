"""A distinct alias over a non-primitive base is rejected."""

obj Payload {
    has v: int = 0;
}

type PayloadRef = distinct Payload;

with entry {
    print(PayloadRef);
}
