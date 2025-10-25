// 全局配置 - 使用独立的管理后台服务器
const API_BASE = 'http://localhost:3002/api';
let currentUser = null;
let authToken = null;

// 页面初始化
document.addEventListener('DOMContentLoaded', function() {
    // 检查登录状态
    checkAuth();
    
    // 设置导航点击事件
    document.querySelectorAll('.sidebar .nav-link').forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            // 移除所有active类
            document.querySelectorAll('.sidebar .nav-link').forEach(l => l.classList.remove('active'));
            // 添加active类到当前链接
            this.classList.add('active');
        });
    });
});

// 认证相关函数
async function checkAuth() {
    const token = localStorage.getItem('auth_token');
    if (!token) {
        showLoginModal();
        return;
    }
    
    authToken = token;
    try {
        const response = await fetch(`${API_BASE}/verify`, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });
        
        if (response.ok) {
            const data = await response.json();
            currentUser = data.user;
            document.getElementById('current-user').textContent = currentUser.realName || currentUser.username;
            loadDashboard();
        } else {
            showLoginModal();
        }
    } catch (error) {
        console.error('认证失败:', error);
        showLoginModal();
    }
}

function showLoginModal() {
    const username = prompt('请输入用户名:');
    const password = prompt('请输入密码:');
    
    if (username && password) {
        login(username, password);
    } else {
        alert('请输入用户名和密码');
        showLoginModal();
    }
}

async function login(username, password) {
    try {
        const response = await fetch(`${API_BASE}/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        const data = await response.json();
        
        if (data.success) {
            authToken = data.token;
            currentUser = data.user;
            localStorage.setItem('auth_token', data.token);
            document.getElementById('current-user').textContent = currentUser.realName || currentUser.username;
            loadDashboard();
        } else {
            alert('登录失败: ' + data.message);
            showLoginModal();
        }
    } catch (error) {
        console.error('登录错误:', error);
        alert('登录失败，请检查网络连接');
        showLoginModal();
    }
}

function logout() {
    localStorage.removeItem('auth_token');
    authToken = null;
    currentUser = null;
    showLoginModal();
}

// 页面切换
function showPage(pageId) {
    // 隐藏所有页面
    document.querySelectorAll('.page-section').forEach(page => {
        page.classList.remove('active');
    });
    
    // 显示目标页面
    document.getElementById(pageId).classList.add('active');
    
    // 更新页面标题
    const titles = {
        'dashboard': '仪表盘',
        'users': '用户管理',
        'roles': '角色管理',
        'permissions': '权限管理',
        'tasks': '任务管理',
        'logs': '日志管理'
    };
    document.getElementById('page-title').textContent = titles[pageId];
    
    // 加载对应数据
    switch(pageId) {
        case 'dashboard':
            loadDashboard();
            break;
        case 'users':
            loadUsers();
            break;
        case 'roles':
            loadRoles();
            break;
        case 'permissions':
            loadPermissions();
            break;
        case 'tasks':
            loadTasks();
            break;
        case 'logs':
            loadLogs();
            break;
    }
}

// 仪表盘数据加载
async function loadDashboard() {
    try {
        // 加载用户统计
        await loadUserStats();
        // 加载任务统计
        await loadTaskStats();
        // 加载日志统计
        await loadLogStats();
        // 加载角色统计
        await loadRoleStats();
    } catch (error) {
        console.error('加载仪表盘数据失败:', error);
    }
}

async function loadUserStats() {
    try {
        // 尝试使用管理员接口获取所有用户
        const response = await fetch(`${API_BASE}/admin/users`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        if (data.success && data.users) {
            document.getElementById('total-users').textContent = data.users.length;
        } else {
            // 如果管理员接口失败，尝试普通用户接口
            const fallbackResponse = await fetch(`${API_BASE}/users`, {
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                }
            });
            const fallbackData = await fallbackResponse.json();
            if (fallbackData.success && fallbackData.users) {
                document.getElementById('total-users').textContent = fallbackData.users.length;
            } else {
                document.getElementById('total-users').textContent = '0';
            }
        }
    } catch (error) {
        console.error('加载用户统计失败:', error);
        document.getElementById('total-users').textContent = '-';
    }
}

async function loadTaskStats() {
    try {
        const response = await fetch(`${API_BASE}/tasks`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        if (data.success && data.tasks) {
            document.getElementById('total-tasks').textContent = data.tasks.length;
        } else {
            document.getElementById('total-tasks').textContent = '0';
        }
    } catch (error) {
        console.error('加载任务统计失败:', error);
        document.getElementById('total-tasks').textContent = '-';
    }
}

async function loadLogStats() {
    try {
        const response = await fetch(`${API_BASE}/logs`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        if (data.success && data.data) {
            document.getElementById('total-logs').textContent = data.data.length;
        } else {
            document.getElementById('total-logs').textContent = '0';
        }
    } catch (error) {
        console.error('加载日志统计失败:', error);
        document.getElementById('total-logs').textContent = '-';
    }
}

async function loadRoleStats() {
    try {
        const response = await fetch(`${API_BASE}/roles`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        if (data.success && data.roles) {
            document.getElementById('total-roles').textContent = data.roles.length;
        } else {
            document.getElementById('total-roles').textContent = '0';
        }
    } catch (error) {
        console.error('加载角色统计失败:', error);
        document.getElementById('total-roles').textContent = '-';
    }
}

// 用户管理
async function loadUsers() {
    try {
        console.log('开始加载用户列表...');
        
        // 首先尝试管理员接口
        const response = await fetch(`${API_BASE}/admin/users`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('管理员接口响应状态:', response.status);
        
        // 检查响应内容类型
        const contentType = response.headers.get('content-type');
        console.log('响应内容类型:', contentType);
        
        if (!contentType || !contentType.includes('application/json')) {
            const text = await response.text();
            console.error('响应不是JSON格式:', text.substring(0, 200));
            throw new Error('API返回非JSON格式，可能是服务器未运行或路径错误');
        }
        
        const data = await response.json();
        console.log('管理员接口响应数据:', data);
        
        if (data.success) {
            displayUsers(data.users);
            return;
        }
        
        // 如果管理员接口失败，尝试调试接口
        console.log('管理员接口失败，尝试调试接口...');
        const debugResponse = await fetch(`${API_BASE}/debug/users`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('调试接口响应状态:', debugResponse.status);
        const debugData = await debugResponse.json();
        console.log('调试接口响应数据:', debugData);
        
        if (debugData.success) {
            displayUsers(debugData.users);
            console.log('调试信息:', debugData.debug);
            return;
        }
        
        // 如果调试接口也失败，尝试普通用户接口
        console.log('调试接口失败，尝试普通用户接口...');
        const fallbackResponse = await fetch(`${API_BASE}/users`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        console.log('普通用户接口响应状态:', fallbackResponse.status);
        const fallbackData = await fallbackResponse.json();
        console.log('普通用户接口响应数据:', fallbackData);
        
        if (fallbackData.success) {
            displayUsers(fallbackData.users);
        } else {
            const errorMsg = data.message || debugData.message || fallbackData.message || '未知错误';
            console.error('所有接口都失败了:', errorMsg);
            showError('加载用户列表失败: ' + errorMsg);
        }
    } catch (error) {
        console.error('加载用户失败:', error);
        showError('加载用户列表失败: ' + error.message);
    }
}

function displayUsers(users) {
    const tbody = document.getElementById('users-table');
    tbody.innerHTML = '';
    
    users.forEach(user => {
        const row = document.createElement('tr');
        
        console.log('显示用户:', user.username, '角色信息:', {
            primaryRole: user.primaryRole,
            allRoles: user.allRoles
        });
        
        // 角色显示逻辑
        let roleDisplay = '';
        if (user.primaryRole) {
            // 如果有多个角色，显示主要角色和提示
            const roleCount = user.allRoles ? user.allRoles.length : 1;
            if (roleCount > 1) {
                roleDisplay = `
                    <span class="badge bg-primary" title="所有角色: ${user.allRoles.join(', ')}">${user.primaryRole}</span>
                    <span class="badge bg-secondary ms-1" title="所有角色: ${user.allRoles.join(', ')}">+${roleCount - 1}</span>
                `;
            } else {
                roleDisplay = `<span class="badge bg-primary">${user.primaryRole}</span>`;
            }
            // 添加管理按钮
            roleDisplay += `
                <button class="btn btn-sm btn-outline-primary ms-1" onclick="assignRole(${user.id})" title="管理角色">
                    <i class="bi bi-gear"></i>
                </button>
            `;
        } else {
            roleDisplay = `
                <span class="text-muted">无角色</span>
                <button class="btn btn-sm btn-primary ms-1" onclick="assignRole(${user.id})" title="分配角色">
                    <i class="bi bi-plus"></i>
                </button>
            `;
        }
        
        row.innerHTML = `
            <td>${user.username}</td>
            <td>${user.real_name || '-'}</td>
            <td>${user.email || '-'}</td>
            <td>${user.position || '-'}</td>
            <td>${roleDisplay}</td>
            <td><span class="badge bg-${user.status === 1 ? 'success' : 'danger'}">${user.status === 1 ? '正常' : '禁用'}</span></td>
            <td>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="editUser(${user.id})" title="编辑用户">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteUser(${user.id})" title="删除用户">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// 角色管理
async function loadRoles() {
    try {
        const response = await fetch(`${API_BASE}/roles`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            displayRoles(data.roles);
        } else {
            showError('加载角色列表失败: ' + data.message);
        }
    } catch (error) {
        console.error('加载角色失败:', error);
        showError('加载角色列表失败');
    }
}

function displayRoles(roles) {
    const tbody = document.getElementById('roles-table');
    tbody.innerHTML = '';
    
    roles.forEach(role => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${role.role_name}</td>
            <td>${role.description || '-'}</td>
            <td><span class="badge bg-info">${role.user_count}</span></td>
            <td>${formatDate(role.created_at)}</td>
            <td>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="editRole(${role.id})">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteRole(${role.id})">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// 权限管理
async function loadPermissions() {
    try {
        const response = await fetch(`${API_BASE}/permissions`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            displayPermissions(data.permissions);
        } else {
            showError('加载权限列表失败: ' + data.message);
        }
    } catch (error) {
        console.error('加载权限失败:', error);
        showError('加载权限列表失败');
    }
}

function displayPermissions(permissions) {
    const tbody = document.getElementById('permissions-table');
    tbody.innerHTML = '';
    
    permissions.forEach(permission => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${permission.name}</td>
            <td><code>${permission.perm_key}</code></td>
            <td><span class="badge bg-secondary">${getModuleDisplayName(permission.module)}</span></td>
            <td>${permission.description || '-'}</td>
            <td>
                <button class="btn btn-sm btn-outline-danger" onclick="deletePermission(${permission.id})" title="删除权限">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// 任务管理
async function loadTasks() {
    try {
        const response = await fetch(`${API_BASE}/tasks`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            displayTasks(data.tasks);
        } else {
            showError('加载任务列表失败: ' + data.message);
        }
    } catch (error) {
        console.error('加载任务失败:', error);
        showError('加载任务列表失败');
    }
}

function displayTasks(tasks) {
    const tbody = document.getElementById('tasks-table');
    tbody.innerHTML = '';
    
    tasks.forEach(task => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${task.name}</td>
            <td><span class="badge bg-${getPriorityColor(task.priority)}">${getPriorityText(task.priority)}</span></td>
            <td>
                <div class="progress" style="height: 20px;">
                    <div class="progress-bar" style="width: ${task.progress}%">${task.progress}%</div>
                </div>
            </td>
            <td>用户${task.owner_user_id}</td>
            <td>${task.due_time ? formatDate(task.due_time) : '-'}</td>
            <td><span class="badge bg-success">进行中</span></td>
        `;
        tbody.appendChild(row);
    });
}

// 日志管理
async function loadLogs() {
    try {
        const response = await fetch(`${API_BASE}/logs`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            displayLogs(data.data);
        } else {
            showError('加载日志列表失败: ' + data.message);
        }
    } catch (error) {
        console.error('加载日志失败:', error);
        showError('加载日志列表失败');
    }
}

function displayLogs(logs) {
    const tbody = document.getElementById('logs-table');
    tbody.innerHTML = '';
    
    logs.forEach(log => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${log.content.length > 50 ? log.content.substring(0, 50) + '...' : log.content}</td>
            <td><span class="badge bg-${getPriorityColor(log.priority)}">${getPriorityText(log.priority)}</span></td>
            <td>用户${log.userId}</td>
            <td>${formatDate(log.createdAt)}</td>
            <td>${log.taskId ? '任务' + log.taskId : '-'}</td>
        `;
        tbody.appendChild(row);
    });
}

// 用户管理模态框
function showUserModal(userId = null) {
    const modal = new bootstrap.Modal(document.getElementById('userModal'));
    const title = document.getElementById('userModalTitle');
    const form = document.getElementById('userForm');
    
    if (userId) {
        title.textContent = '编辑用户';
        currentEditingUserId = userId;
        loadUserData(userId);
    } else {
        title.textContent = '添加用户';
        currentEditingUserId = null;
        form.reset();
        // 重置密码字段
        document.getElementById('password').placeholder = '请输入密码';
    }
    
    // 加载角色选项
    loadRoleOptions();
    
    modal.show();
}

// 加载用户数据用于编辑
async function loadUserData(userId) {
    try {
        const response = await fetch(`${API_BASE}/users/${userId}`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            const user = data.user;
            document.getElementById('username').value = user.username || '';
            document.getElementById('realName').value = user.real_name || '';
            document.getElementById('email').value = user.email || '';
            document.getElementById('phone').value = user.phone || '';
            document.getElementById('position').value = user.position || '';
            // 密码字段在编辑时留空
            document.getElementById('password').value = '';
            document.getElementById('password').placeholder = '留空表示不修改密码';
        }
    } catch (error) {
        console.error('加载用户数据失败:', error);
        showError('加载用户数据失败');
    }
}

function loadRoleOptions() {
    // 这里应该从API加载角色列表
    const select = document.getElementById('userRoles');
    select.innerHTML = `
        <option value="1">创始人</option>
        <option value="2">管理员</option>
        <option value="3">部门负责人</option>
        <option value="4">普通员工</option>
    `;
}

// 全局变量存储当前编辑的用户ID和角色ID
let currentEditingUserId = null;
let currentEditingRoleId = null;

async function saveUser() {
    const formData = {
        username: document.getElementById('username').value,
        realName: document.getElementById('realName').value,
        email: document.getElementById('email').value,
        phone: document.getElementById('phone').value,
        position: document.getElementById('position').value
    };
    
    // 只有在创建用户或修改密码时才包含密码
    const password = document.getElementById('password').value;
    if (password && password.trim() !== '') {
        formData.password = password;
    }
    
    try {
        let response;
        let successMessage;
        
        if (currentEditingUserId) {
            // 编辑用户
            response = await fetch(`${API_BASE}/users/${currentEditingUserId}`, {
                method: 'PUT',
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });
            successMessage = '用户更新成功';
        } else {
            // 创建用户
            if (!formData.password) {
                showError('创建用户时密码不能为空');
                return;
            }
            response = await fetch(`${API_BASE}/register`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });
            successMessage = '用户创建成功';
        }
        
        const data = await response.json();
        
        if (data.success) {
            showSuccess(successMessage);
            bootstrap.Modal.getInstance(document.getElementById('userModal')).hide();
            currentEditingUserId = null;
            loadUsers();
        } else {
            showError((currentEditingUserId ? '更新' : '创建') + '用户失败: ' + data.message);
        }
    } catch (error) {
        console.error('保存用户失败:', error);
        showError('保存用户失败');
    }
}

// 角色管理模态框
function showRoleModal(roleId = null) {
    const modal = new bootstrap.Modal(document.getElementById('roleModal'));
    const title = document.getElementById('roleModalTitle');
    const form = document.getElementById('roleForm');
    
    if (roleId) {
        title.textContent = '编辑角色';
        currentEditingRoleId = roleId;
        loadRoleData(roleId);
    } else {
        title.textContent = '添加角色';
        currentEditingRoleId = null;
        form.reset();
    }
    
    // 加载权限选项
    loadPermissionOptions();
    
    modal.show();
}

// 加载角色数据用于编辑
async function loadRoleData(roleId) {
    try {
        const response = await fetch(`${API_BASE}/roles/${roleId}/permissions`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            // 设置已选中的权限
            setTimeout(() => {
                data.permissions.forEach(permission => {
                    const checkbox = document.getElementById(`perm_${permission.id}`);
                    if (checkbox) {
                        checkbox.checked = true;
                    }
                });
            }, 500); // 等待权限选项加载完成
        }
    } catch (error) {
        console.error('加载角色数据失败:', error);
        showError('加载角色数据失败');
    }
}

async function loadPermissionOptions() {
    try {
        const response = await fetch(`${API_BASE}/permissions`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success && data.permissions) {
            // 按模块分组权限
            const permissionsByModule = {};
            data.permissions.forEach(permission => {
                if (!permissionsByModule[permission.module]) {
                    permissionsByModule[permission.module] = [];
                }
                permissionsByModule[permission.module].push(permission);
            });
            
            // 生成权限选择界面
            let html = '<div class="row">';
            Object.keys(permissionsByModule).forEach(module => {
                const moduleName = getModuleDisplayName(module);
                html += `
                    <div class="col-md-6 mb-3">
                        <h6>${moduleName}</h6>
                        <div class="permission-group">
                `;
                
                permissionsByModule[module].forEach(permission => {
                    html += `
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" value="${permission.id}" id="perm_${permission.id}">
                            <label class="form-check-label" for="perm_${permission.id}">
                                ${permission.name}
                                <small class="text-muted d-block">${permission.description || ''}</small>
                            </label>
                        </div>
                    `;
                });
                
                html += `
                        </div>
                    </div>
                `;
            });
            html += '</div>';
            
            document.getElementById('permissions-list').innerHTML = html;
        } else {
            showError('加载权限列表失败');
        }
    } catch (error) {
        console.error('加载权限选项失败:', error);
        showError('加载权限列表失败');
    }
}

function getModuleDisplayName(module) {
    const moduleNames = {
        'user_management': '用户管理',
        'task_management': '任务管理',
        'log_management': '日志管理',
        'role_management': '角色管理',
        'system_management': '系统管理'
    };
    return moduleNames[module] || module;
}

async function saveRole() {
    const formData = {
        roleName: document.getElementById('roleName').value,
        description: document.getElementById('roleDescription').value
    };
    
    // 获取选中的权限
    const checkboxes = document.querySelectorAll('#permissions-list input[type="checkbox"]:checked');
    const permissionIds = Array.from(checkboxes).map(cb => parseInt(cb.value));
    
    if (!formData.roleName) {
        showError('角色名称不能为空');
        return;
    }
    
    try {
        let response;
        let successMessage;
        
        if (currentEditingRoleId) {
            // 编辑角色
            response = await fetch(`${API_BASE}/roles/${currentEditingRoleId}`, {
                method: 'PUT',
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });
            successMessage = '角色更新成功';
        } else {
            // 创建角色
            response = await fetch(`${API_BASE}/roles`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });
            successMessage = '角色创建成功';
        }
        
        const data = await response.json();
        
        if (data.success) {
            const roleId = data.role?.id || currentEditingRoleId;
            
            // 分配权限
            if (roleId && permissionIds.length > 0) {
                const permResponse = await fetch(`${API_BASE}/roles/${roleId}/permissions`, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${authToken}`,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ permissionIds })
                });
                
                const permData = await permResponse.json();
                if (!permData.success) {
                    showError('角色创建成功，但权限分配失败: ' + permData.message);
                    return;
                }
            }
            
            showSuccess(successMessage);
            bootstrap.Modal.getInstance(document.getElementById('roleModal')).hide();
            currentEditingRoleId = null;
            loadRoles();
        } else {
            showError((currentEditingRoleId ? '更新' : '创建') + '角色失败: ' + data.message);
        }
    } catch (error) {
        console.error('保存角色失败:', error);
        showError('保存角色失败: ' + error.message);
    }
}

// 工具函数
function formatDate(dateString) {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('zh-CN') + ' ' + date.toLocaleTimeString('zh-CN');
}

function getPriorityColor(priority) {
    const colors = {
        'high': 'danger',
        'medium': 'warning',
        'low': 'success'
    };
    return colors[priority] || 'secondary';
}

function getPriorityText(priority) {
    const texts = {
        'high': '高',
        'medium': '中',
        'low': '低'
    };
    return texts[priority] || priority;
}

function showSuccess(message) {
    // 这里可以添加更好的通知组件
    alert('成功: ' + message);
}

function showError(message) {
    // 这里可以添加更好的通知组件
    alert('错误: ' + message);
}

// 角色分配功能
async function assignRole(userId) {
    try {
        // 获取所有角色
        const rolesResponse = await fetch(`${API_BASE}/roles`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const rolesData = await rolesResponse.json();
        if (!rolesData.success) {
            showError('获取角色列表失败');
            return;
        }
        
        // 获取用户当前角色
        const userRolesResponse = await fetch(`${API_BASE}/user-roles/${userId}`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const userRolesData = await userRolesResponse.json();
        const currentRoleIds = userRolesData.success ? userRolesData.roles.map(r => r.id) : [];
        
        // 创建角色选择对话框
        const roleOptions = rolesData.roles.map(role => 
            `<div class="form-check">
                <input class="form-check-input" type="checkbox" value="${role.id}" id="role_${role.id}" ${currentRoleIds.includes(role.id) ? 'checked' : ''}>
                <label class="form-check-label" for="role_${role.id}">
                    ${role.role_name} - ${role.description || ''}
                </label>
            </div>`
        ).join('');
        
        const modalHtml = `
            <div class="modal fade" id="roleAssignModal" tabindex="-1">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">分配角色</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-3">
                                <label class="form-label">选择角色</label>
                                ${roleOptions}
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">取消</button>
                            <button type="button" class="btn btn-primary" onclick="saveUserRoles(${userId})">保存</button>
                        </div>
                    </div>
                </div>
            </div>
        `;
        
        // 移除旧的模态框
        const oldModal = document.getElementById('roleAssignModal');
        if (oldModal) {
            oldModal.remove();
        }
        
        // 添加新的模态框
        document.body.insertAdjacentHTML('beforeend', modalHtml);
        
        // 显示模态框
        const modal = new bootstrap.Modal(document.getElementById('roleAssignModal'));
        modal.show();
        
    } catch (error) {
        console.error('分配角色失败:', error);
        showError('分配角色失败: ' + error.message);
    }
}

async function saveUserRoles(userId) {
    try {
        const checkboxes = document.querySelectorAll('#roleAssignModal input[type="checkbox"]:checked');
        const roleIds = Array.from(checkboxes).map(cb => parseInt(cb.value));
        
        const response = await fetch(`${API_BASE}/user-roles/${userId}`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ roleIds })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showSuccess('角色分配成功');
            bootstrap.Modal.getInstance(document.getElementById('roleAssignModal')).hide();
            loadUsers(); // 重新加载用户列表
        } else {
            showError('角色分配失败: ' + data.message);
        }
    } catch (error) {
        console.error('保存用户角色失败:', error);
        showError('保存用户角色失败: ' + error.message);
    }
}

// 权限管理模态框
function showPermissionModal() {
    const modal = new bootstrap.Modal(document.getElementById('permissionModal'));
    const form = document.getElementById('permissionForm');
    
    // 重置表单
    form.reset();
    document.getElementById('permissionModalTitle').textContent = '添加权限';
    
    modal.show();
}

async function savePermission() {
    const formData = {
        permKey: document.getElementById('permKey').value.trim(),
        name: document.getElementById('permName').value.trim(),
        module: document.getElementById('permModule').value,
        description: document.getElementById('permDescription').value.trim()
    };
    
    if (!formData.permKey || !formData.name || !formData.module) {
        showError('权限键、名称和模块不能为空');
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/permissions`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(formData)
        });
        
        const data = await response.json();
        
        if (data.success) {
            showSuccess('权限创建成功');
            bootstrap.Modal.getInstance(document.getElementById('permissionModal')).hide();
            loadPermissions();
        } else {
            showError('创建权限失败: ' + data.message);
        }
    } catch (error) {
        console.error('保存权限失败:', error);
        showError('保存权限失败: ' + error.message);
    }
}

async function deletePermission(permissionId) {
    if (!confirm('确定要删除这个权限吗？\n\n删除权限将同时删除所有角色的该权限关联。此操作不可撤销！')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/permissions/${permissionId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            showSuccess('权限删除成功');
            loadPermissions();
        } else {
            showError('删除权限失败: ' + data.message);
        }
    } catch (error) {
        console.error('删除权限失败:', error);
        showError('删除权限失败: ' + error.message);
    }
}

// 编辑和删除函数
function editUser(userId) {
    showUserModal(userId);
}

async function deleteUser(userId) {
    if (confirm('⚠️ 警告：确定要删除这个用户吗？\n\n这将永久删除用户及其关联数据，此操作不可撤销！')) {
        try {
            const response = await fetch(`${API_BASE}/users/${userId}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                }
            });
            
            const data = await response.json();
            
            if (data.success) {
                showSuccess('用户已永久删除');
                loadUsers();
            } else {
                showError('删除用户失败: ' + data.message);
            }
        } catch (error) {
            console.error('删除用户失败:', error);
            showError('删除用户失败: ' + error.message);
        }
    }
}

function editRole(roleId) {
    showRoleModal(roleId);
}

async function deleteRole(roleId) {
    if (confirm('确定要删除这个角色吗？此操作不可撤销！')) {
        try {
            const response = await fetch(`${API_BASE}/roles/${roleId}`, {
                method: 'DELETE',
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                }
            });
            
            const data = await response.json();
            
            if (data.success) {
                showSuccess('角色删除成功');
                loadRoles();
            } else {
                showError('删除角色失败: ' + data.message);
            }
        } catch (error) {
            console.error('删除角色失败:', error);
            showError('删除角色失败: ' + error.message);
        }
    }
}
