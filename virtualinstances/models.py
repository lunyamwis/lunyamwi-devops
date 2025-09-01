from django.db import models

# Create your models here.
class Instance(models.Model):
    name = models.CharField(max_length=50)
    ip = models.CharField(max_length=20)

    def __str__(self) -> str:
        return self.name