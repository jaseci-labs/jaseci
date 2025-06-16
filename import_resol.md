
![alt text](<Screenshot 2025-06-16 192317.png>)


<br>
<br>
<br>


In this PR, currently handling  `built-in` or `standard` modules are not handled yet.


![alt text](image.png)


also we need to consider the 
`sys.path` and `PYTHONPATH` environment variable to resolve the modules correctly.
will be handled in the next PR.


if it is not a import *, we don't need to handle all import
![alt text](image-1.png)

this will only import main.a,b only 



## unexpected !!!! 

![alt text](image-2.png)

this will parse requests and math also !!!