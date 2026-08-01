# Ubuntu set
```bash
# clear history
 cat /dev/null > ~/.bash_history && history -c
````
 
 
 ## python set up
``` bash
In case need clean installation
# Delete Packages  ~/.local (ระดับ User System)
rm -rf ~/.local/lib/python*
rm -rf ~/.local/bin/pip*

# Purge python3-pip delete all  config 
sudo apt purge -y python3-pip python3-venv

# Clean 
sudo apt autoremove -y
sudo apt clean
```

```bash
#prepare machine
sudo apt update
sudo apt update
#install Python 3, Pip and Virtual Environment Tool
sudo apt install -y python3 python3-pip python3-venv build-essential
#OpenMPI System Libraries (parallel computing)
sudo apt install -y openmpi-bin libopenmpi-dev

 # virtual environment
python3 -m venv gpu_env
#call
source gpu_env/bin/activate #quit with  deactivate
#set MPI
echo "export OMPI_MCA_btl_tcp_if_include=lo" >> ~/.bashrc
export OMPI_MCA_btl_tcp_if_include=lo
#install package
python -m pip install --upgrade pip
python -m pip install numpy matplotlib pyopencl numba mpi4py

# Sanity Check

python --version
python -m pip list
#check  NumPy, Matplotlib & Numba
python -c "import numpy, matplotlib, numba; print('Core Libs: OK!')"
#check PyOpenCL (GPU)
python -c "import pyopencl as cl; print('GPU Devices:', cl.get_platforms()[0].get_devices())"
#check MPI
mpirun -np 4 python -c "from mpi4py import MPI; print(f'Rank {MPI.COMM_WORLD.Get_rank()} OK!')"
```





## VS code
```bash
### Dependencies
sudo apt update
sudo apt install software-properties-common apt-transport-https wget -y
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

### Add Repo
sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

### install
sudo apt update
sudo apt install code

### Launching
code
#########################################################################################################
```
## AntiGravity
```bash
curl -fsSL https://antigravity.google/cli/install.sh | bash
agy --version
agy
```
