# serializers.py
from rest_framework import serializers
from .models import Instance

class InstanceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Instance
        fields = '__all__'
        extra_kwargs = {
            "id": {"required": False, "allow_null": True},
        }
        
class CreateVMRequestSerializer(serializers.Serializer):
    # Define fields for your input data
    field1 = serializers.CharField(default="test")
    # field2 = serializers.IntegerField()
    # Add more fields as needed
