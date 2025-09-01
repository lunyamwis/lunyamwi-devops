
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
#router.register(r'instance', views.ScoreViewSet)


urlpatterns = [
    path('', include(router.urls)),
    path('create_vm_and_run_docker/', views.CreateVMAndRunDockerAPIView.as_view(), name='create_vm_and_run_docker'),
]
