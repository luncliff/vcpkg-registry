
[string]$DownloadUrl="https://developer.download.nvidia.com/compute/machine-learning/tensorrt/10.9.0/zip/TensorRT-10.9.0.34.Windows.win10.cuda-12.8.zip"
[string]$DownloadPath="TensorRT-10.9.cuda-12.8.zip"
Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadPath

# Expand-Archive -Path $DownloadPath -DestinationPath "$env:CUDA_PATH"