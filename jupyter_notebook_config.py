import os

c.NotebookApp.notebook_dir = os.environ.get('HOME')

c.ServerApp.ip = '0.0.0.0'
c.ServerApp.open_browser = False
c.ServerApp.allow_root = True
# 端口必须是 8888
c.ServerApp.port = 8888
c.ServerApp.autoreload = True

# token / password 由环境变量注入
c.ServerApp.token = os.environ.get('JUPYTER_TOKEN', '')
c.IdentityProvider.token = os.environ.get('JUPYTER_TOKEN', '')
if 'JUPYTER_PASSWORD' in os.environ:
    c.ServerApp.password = os.environ.get('JUPYTER_PASSWORD')
    c.NotebookApp.password = os.environ.get('JUPYTER_PASSWORD')

# Allow front page embedding
if 'ORIGIN' in os.environ:
    c.ServerApp.allow_origin = os.environ.get('ORIGIN')
if 'NB_PREFIX' in os.environ:
    c.ServerApp.base_url = os.environ.get('NB_PREFIX')

# Display hidden files in the file browser side panel
c.ContentsManager.allow_hidden = True
c.ServerApp.authenticate_prometheus = True
c.NotebookNotary.db_file = '/tmp/signature.db'

# 兼容 notebook 6.x（NotebookApp）与 jupyterlab 3.x（ServerApp）双入口
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.open_browser = False
c.NotebookApp.allow_root = True
c.NotebookApp.port = 8888
c.NotebookApp.allow_hidden = True
