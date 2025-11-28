// 全局配置 - 使用独立的管理后台服务器
const API_BASE = 'http://localhost:3002/api';
let currentUser = null;
let authToken = null;

// 数据缓存（减少重复请求）
const dataCache = {
  users: { data: null, timestamp: 0, ttl: 30000 }, // 30秒缓存
  roles: { data: null, timestamp: 0, ttl: 60000 }, // 60秒缓存
  permissions: { data: null, timestamp: 0, ttl: 60000 }, // 60秒缓存
  tasks: { data: null, timestamp: 0, ttl: 10000 }, // 10秒缓存
  logs: { data: null, timestamp: 0, ttl: 10000 }, // 10秒缓存
  topItems: { data: null, timestamp: 0, ttl: 60000 }, // 60秒缓存
};

// 防抖函数
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// 检查缓存是否有效
function isCacheValid(cacheKey) {
  const cache = dataCache[cacheKey];
  if (!cache || !cache.data) return false;
  return Date.now() - cache.timestamp < cache.ttl;
}

// 清除缓存
function clearCache(cacheKey) {
  if (cacheKey) {
    dataCache[cacheKey] = { data: null, timestamp: 0, ttl: dataCache[cacheKey]?.ttl || 0 };
  } else {
    // 清除所有缓存
    Object.keys(dataCache).forEach(key => {
      dataCache[key] = { data: null, timestamp: 0, ttl: dataCache[key].ttl };
    });
  }
}

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
        console.log('开始登录请求，API地址:', `${API_BASE}/login`);
        const response = await fetch(`${API_BASE}/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
        
        console.log('登录响应状态:', response.status, response.statusText);
        
        // 检查响应状态
        if (!response.ok) {
            // 尝试解析错误消息
            let errorMessage = `HTTP ${response.status}: ${response.statusText}`;
            try {
                const errorData = await response.json();
                if (errorData.message) {
                    errorMessage = errorData.message;
                }
            } catch (e) {
                // 如果无法解析JSON，使用默认错误消息
                const text = await response.text();
                console.error('响应内容（非JSON）:', text.substring(0, 200));
            }
            alert('登录失败: ' + errorMessage);
            showLoginModal();
            return;
        }
        
        // 解析成功响应
        const data = await response.json();
        console.log('登录响应数据:', data);
        
        if (data.success) {
            authToken = data.token;
            currentUser = data.user;
            localStorage.setItem('auth_token', data.token);
            document.getElementById('current-user').textContent = currentUser.realName || currentUser.username;
            loadDashboard();
        } else {
            alert('登录失败: ' + (data.message || '未知错误'));
            showLoginModal();
        }
    } catch (error) {
        console.error('登录错误:', error);
        // 更详细的错误信息
        let errorMessage = '登录失败，请检查网络连接';
        if (error.message) {
            errorMessage += '\n错误详情: ' + error.message;
        }
        if (error.name === 'TypeError' && error.message.includes('fetch')) {
            errorMessage += '\n\n可能的原因:\n1. 后端服务器未运行\n2. API地址错误\n3. CORS跨域问题\n\n请确认后端服务器运行在 http://localhost:3002';
        }
        alert(errorMessage);
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
        'logs': '日志管理',
        'top-items': '公司十大事项管理'
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
        case 'top-items':
            loadTopItems();
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
        const response = await fetch(`${API_BASE}/users/stats`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        if (data.success && typeof data.totalUsers === 'number') {
            document.getElementById('total-users').textContent = data.totalUsers;
            return;
        }

        document.getElementById('total-users').textContent = '0';
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

// 用户管理（带缓存优化）
async function loadUsers(forceRefresh = false) {
    try {
        // 检查 token
        if (!authToken) {
            const token = localStorage.getItem('auth_token');
            if (token) {
                authToken = token;
            } else {
                console.error('未找到认证token，需要重新登录');
                showError('未登录，请重新登录');
                checkAuth();
                return;
            }
        }
        
        // 检查缓存
        if (!forceRefresh && isCacheValid('users')) {
            console.log('使用缓存的用户列表');
            displayUsers(dataCache.users.data.users || dataCache.users.data, dataCache.users.data.pagination);
            return;
        }
        
        console.log('开始加载用户列表...');
        console.log('API地址:', `${API_BASE}/admin/users`);
        console.log('Token存在:', !!authToken);
        
        const page = 1;
        const pageSize = 20;
        
        let response;
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 12000); // 12秒超时
        
        try {
            response = await fetch(`${API_BASE}/admin/users?page=${page}&pageSize=${pageSize}`, {
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                },
                signal: controller.signal
            });
        } catch (fetchError) {
            clearTimeout(timeoutId);
            console.error('网络请求失败:', fetchError);
            if (fetchError.name === 'AbortError' || fetchError.message.includes('aborted')) {
                throw new Error('请求超时（12秒），请检查后端服务器是否正常运行');
            }
            if (fetchError.message.includes('Failed to fetch') || fetchError.name === 'TypeError') {
                throw new Error('无法连接到后端服务器。请确认:\n1. 后端服务器运行在 http://localhost:3002\n2. 网络连接正常\n3. 没有CORS错误');
            }
            throw fetchError;
        } finally {
            clearTimeout(timeoutId);
        }
        
        console.log('管理员接口响应状态:', response.status);
        
        // 检查响应状态
        if (!response.ok) {
            // 如果是401未授权，可能是token失效
            if (response.status === 401) {
                console.error('Token无效，需要重新登录');
                localStorage.removeItem('auth_token');
                authToken = null;
                showError('登录已过期，请重新登录');
                checkAuth();
                return;
            }
            
            // 尝试解析错误消息
            let errorMessage = `HTTP ${response.status}: ${response.statusText}`;
            try {
                const errorData = await response.json();
                if (errorData.message) {
                    errorMessage = errorData.message;
                }
            } catch (e) {
                // 如果无法解析JSON，尝试读取文本
                try {
                    const text = await response.text();
                    console.error('错误响应内容:', text.substring(0, 200));
                } catch (textError) {
                    console.error('无法读取错误响应');
                }
            }
            throw new Error(errorMessage);
        }
        
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
            const cachePayload = { users: data.users, pagination: data.pagination };
            dataCache.users = { data: cachePayload, timestamp: Date.now(), ttl: dataCache.users.ttl };
            displayUsers(data.users, data.pagination);
            return;
        } else {
            throw new Error(data.message || '加载用户列表失败');
        }
    } catch (error) {
        console.error('加载用户失败:', error);
        
        // 更友好的错误提示
        let errorMessage = error.message || '未知错误';
        
        if (errorMessage.includes('Failed to fetch') || errorMessage.includes('无法连接')) {
            errorMessage = '无法连接到后端服务器\n\n可能的原因:\n1. 后端服务器未运行\n2. 服务器地址错误\n3. 网络连接问题\n4. CORS跨域限制\n\n请检查后端服务器是否在 http://localhost:3002 运行';
        }
        
        showError('加载用户列表失败: ' + errorMessage);
    }
}

function displayUsers(users, pagination) {
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
        
        // 部门显示逻辑
        let departmentDisplay = '';
        if (user.department_name) {
            departmentDisplay = `
                <span class="badge bg-info">${user.department_name}</span>
                <button class="btn btn-sm btn-outline-info ms-1" onclick="assignDepartment(${user.id})" title="编辑部门">
                    <i class="bi bi-gear"></i>
                </button>
            `;
        } else {
            departmentDisplay = `
                <span class="text-muted">无部门</span>
                <button class="btn btn-sm btn-info ms-1" onclick="assignDepartment(${user.id})" title="分配部门">
                    <i class="bi bi-plus"></i>
                </button>
            `;
        }
        
        // MBTI显示逻辑
        let mbitDisplay = '';
        if (user.mbit) {
            mbitDisplay = `
                <span class="badge bg-warning text-dark">${user.mbit}</span>
                <button class="btn btn-sm btn-outline-warning ms-1" onclick="assignMBTI(${user.id})" title="编辑MBTI">
                    <i class="bi bi-gear"></i>
                </button>
            `;
        } else {
            mbitDisplay = `
                <span class="text-muted">未设置</span>
                <button class="btn btn-sm btn-warning ms-1" onclick="assignMBTI(${user.id})" title="设置MBTI">
                    <i class="bi bi-plus"></i>
                </button>
            `;
        }
        
        row.innerHTML = `
            <td>${user.username}</td>
            <td>${user.real_name || '-'}</td>
            <td>${user.email || '-'}</td>
            <td>${roleDisplay}</td>
            <td>${departmentDisplay}</td>
            <td>${mbitDisplay}</td>
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

// 角色管理（带缓存优化）
async function loadRoles(forceRefresh = false) {
    try {
        // 检查缓存
        if (!forceRefresh && isCacheValid('roles')) {
            console.log('使用缓存的角色列表');
            displayRoles(dataCache.roles.data);
            return;
        }
        
        const response = await fetch(`${API_BASE}/roles`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            // 更新缓存
            dataCache.roles = { data: data.roles, timestamp: Date.now(), ttl: dataCache.roles.ttl };
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

// 权限管理（带缓存优化）
async function loadPermissions(forceRefresh = false) {
    try {
        // 检查缓存
        if (!forceRefresh && isCacheValid('permissions')) {
            console.log('使用缓存的权限列表');
            displayPermissions(dataCache.permissions.data);
            return;
        }
        
        const response = await fetch(`${API_BASE}/permissions`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            // 更新缓存
            dataCache.permissions = { data: data.permissions, timestamp: Date.now(), ttl: dataCache.permissions.ttl };
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

// 任务管理（带缓存优化）
async function loadTasks(forceRefresh = false) {
    try {
        // 检查缓存
        if (!forceRefresh && isCacheValid('tasks')) {
            console.log('使用缓存的任务列表');
            displayTasks(dataCache.tasks.data);
            return;
        }
        
        const response = await fetch(`${API_BASE}/tasks`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            // 更新缓存
            dataCache.tasks = { data: data.tasks, timestamp: Date.now(), ttl: dataCache.tasks.ttl };
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
    
    if (tasks.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" class="text-center">暂无任务</td></tr>';
        return;
    }
    
    tasks.forEach(task => {
        const row = document.createElement('tr');
        // 优先使用后端返回的 assignee 对象（更明确）：assignee.realName -> assignee.username -> 回退到 id 字段
        const assigneeObj = task.assignee || {};
        const assigneeText = assigneeObj.realName || assigneeObj.username || (task.assignee_id ? ('用户' + task.assignee_id) : (task.owner_user_id ? ('用户' + task.owner_user_id) : '-'));
        
        // 状态显示
        const statusBadge = getStatusBadge(task.status);
        
        row.innerHTML = `
            <td>${task.name || '-'}</td>
            <td><span class="badge bg-${getPriorityColor(task.priority)}">${getPriorityText(task.priority)}</span></td>
            <td>
                <div class="progress" style="height: 20px;">
                    <div class="progress-bar" style="width: ${task.progress || 0}%">${task.progress || 0}%</div>
                </div>
            </td>
            <td>${assigneeText}</td>
            <td>${task.due_time ? formatDate(task.due_time) : '-'}</td>
            <td>${statusBadge}</td>
            <td>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="editTask(${task.id})" title="编辑任务">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteTask(${task.id})" title="删除任务">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

function getStatusBadge(status) {
    const statusMap = {
        'pending': { text: '待处理', color: 'warning' },
        'in_progress': { text: '进行中', color: 'primary' },
        'completed': { text: '已完成', color: 'success' },
        'cancelled': { text: '已取消', color: 'secondary' }
    };
    const statusInfo = statusMap[status] || { text: status, color: 'secondary' };
    return `<span class="badge bg-${statusInfo.color}">${statusInfo.text}</span>`;
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
    
    if (logs.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">暂无日志</td></tr>';
        return;
    }
    
    logs.forEach(log => {
        const row = document.createElement('tr');
        const contentPreview = log.content && log.content.length > 50 ? log.content.substring(0, 50) + '...' : (log.content || '-');
        const authorName = log.realName || log.username || `用户${log.userId}`;
        
        row.innerHTML = `
            <td>${contentPreview}</td>
            <td><span class="badge bg-${getPriorityColor(log.priority)}">${getPriorityText(log.priority)}</span></td>
            <td>${authorName}</td>
            <td>${formatDate(log.createdAt)}</td>
            <td>${log.taskId ? '任务' + log.taskId : '-'}</td>
            <td>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="viewLogDetail(${log.id})" title="查看详情">
                    <i class="bi bi-eye"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteLog(${log.id})" title="删除日志">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// 用户管理模态框
async function showUserModal(userId = null) {
    const modal = new bootstrap.Modal(document.getElementById('userModal'));
    const title = document.getElementById('userModalTitle');
    const form = document.getElementById('userForm');
    
    if (userId) {
        title.textContent = '编辑用户';
        currentEditingUserId = userId;
        await loadUserData(userId);
    } else {
        title.textContent = '添加用户';
        currentEditingUserId = null;
        form.reset();
        // 重置密码字段
        document.getElementById('password').placeholder = '请输入密码';
    }
    
    // 加载角色选项
    await loadRoleOptions();
    
    modal.show();
}

// 加载用户数据用于编辑
async function loadUserData(userId) {
    try {
        // 加载用户基本信息
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
            document.getElementById('departmentId').value = user.departmentId || '';
            document.getElementById('mbit').value = user.mbit || '';
            // 密码字段在编辑时留空
            document.getElementById('password').value = '';
            document.getElementById('password').placeholder = '留空表示不修改密码';
        }
        
        // 加载用户的角色
        try {
            const roleResponse = await fetch(`${API_BASE}/user-roles/${userId}`, {
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                }
            });
            
            const roleData = await roleResponse.json();
            const roleSelect = document.getElementById('userRoles');
            
            if (roleData.success && roleData.roles) {
                // 清除之前的选择
                Array.from(roleSelect.options).forEach(option => {
                    option.selected = false;
                });
                
                // 设置用户当前的角色为选中状态
                const currentRoleIds = roleData.roles.map(r => r.id.toString());
                Array.from(roleSelect.options).forEach(option => {
                    if (currentRoleIds.includes(option.value)) {
                        option.selected = true;
                    }
                });
            }
        } catch (roleError) {
            console.error('加载用户角色失败:', roleError);
        }
    } catch (error) {
        console.error('加载用户数据失败:', error);
        showError('加载用户数据失败');
    }
}

async function loadRoleOptions() {
    try {
        const response = await fetch(`${API_BASE}/roles`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        const select = document.getElementById('userRoles');
        
        if (data.success && data.roles) {
            select.innerHTML = '';
            data.roles.forEach(role => {
                const option = document.createElement('option');
                option.value = role.id;
                option.textContent = `${role.role_name}${role.description ? ' - ' + role.description : ''}`;
                select.appendChild(option);
            });
        } else {
            select.innerHTML = '<option value="">加载角色失败</option>';
        }
    } catch (error) {
        console.error('加载角色选项失败:', error);
        const select = document.getElementById('userRoles');
        select.innerHTML = '<option value="">加载角色失败</option>';
    }
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
        departmentId: document.getElementById('departmentId').value ? parseInt(document.getElementById('departmentId').value) : null,
        mbit: document.getElementById('mbit').value || null
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
            // 获取选中的角色
            const roleSelect = document.getElementById('userRoles');
            const selectedRoles = Array.from(roleSelect.selectedOptions).map(option => parseInt(option.value));
            
            // 确定用户ID（创建用户时从响应中获取，编辑用户时使用currentEditingUserId）
            const userId = currentEditingUserId || (data.user && data.user.id);
            
            // 分配或更新角色
            if (userId) {
                try {
                    const roleResponse = await fetch(`${API_BASE}/user-roles/${userId}`, {
                        method: 'POST',
                        headers: {
                            'Authorization': `Bearer ${authToken}`,
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ roleIds: selectedRoles })
                    });
                    
                    const roleData = await roleResponse.json();
                    if (!roleData.success) {
                        console.warn('用户保存成功，但角色分配失败:', roleData.message);
                        showError('用户保存成功，但角色分配失败: ' + roleData.message);
                        return;
                    }
                } catch (roleError) {
                    console.error('分配角色失败:', roleError);
                    showError('用户保存成功，但角色分配失败: ' + roleError.message);
                    return;
                }
            }
            
            showSuccess(successMessage);
            bootstrap.Modal.getInstance(document.getElementById('userModal')).hide();
            currentEditingUserId = null;
            clearCache('users'); // 清除缓存，强制刷新
            loadUsers(true);
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
            clearCache('roles'); // 清除缓存，强制刷新
            loadRoles(true);
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
            clearCache('users'); // 清除缓存，强制刷新
            loadUsers(true); // 重新加载用户列表
        } else {
            showError('角色分配失败: ' + data.message);
        }
    } catch (error) {
        console.error('保存用户角色失败:', error);
        showError('保存用户角色失败: ' + error.message);
    }
}

async function assignDepartment(userId) {
    try {
        // 获取用户当前部门
        const userResponse = await fetch(`${API_BASE}/users/${userId}`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const userData = await userResponse.json();
        const currentDepartmentId = userData.success && userData.user ? userData.user.departmentId : null;
        
        // 创建部门ID输入框（因为目前没有departments表，直接输入部门ID）
        const modalHtml = `
            <div class="modal fade" id="departmentAssignModal" tabindex="-1">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">分配部门</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-3">
                                <label class="form-label">部门ID</label>
                                <input type="number" class="form-control" id="departmentIdInput" 
                                       value="${currentDepartmentId || ''}" 
                                       placeholder="请输入部门ID（留空表示无部门）">
                                <small class="form-text text-muted">目前系统使用部门ID，直接输入数字ID即可</small>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">取消</button>
                            <button type="button" class="btn btn-primary" onclick="saveUserDepartment(${userId})">保存</button>
                        </div>
                    </div>
                </div>
            </div>
        `;
        
        // 移除旧的模态框
        const oldModal = document.getElementById('departmentAssignModal');
        if (oldModal) {
            oldModal.remove();
        }
        
        // 添加新的模态框
        document.body.insertAdjacentHTML('beforeend', modalHtml);
        
        // 显示模态框
        const modal = new bootstrap.Modal(document.getElementById('departmentAssignModal'));
        modal.show();
        
    } catch (error) {
        console.error('分配部门失败:', error);
        showError('分配部门失败: ' + error.message);
    }
}

async function saveUserDepartment(userId) {
    try {
        const departmentIdInput = document.getElementById('departmentIdInput');
        const departmentIdValue = departmentIdInput.value.trim();
        const departmentId = departmentIdValue === '' ? null : parseInt(departmentIdValue);
        
        // 验证输入
        if (departmentIdValue !== '' && (isNaN(departmentId) || departmentId <= 0)) {
            showError('请输入有效的部门ID（正整数）');
            return;
        }
        
        const response = await fetch(`${API_BASE}/users/${userId}`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ departmentId: departmentId })
        });
        
        // 检查响应状态
        if (!response.ok) {
            const errorText = await response.text();
            console.error('服务器错误响应:', errorText);
            throw new Error(`HTTP ${response.status}: ${errorText.substring(0, 100)}`);
        }
        
        const data = await response.json();
        
        if (data.success) {
            showSuccess('部门分配成功');
            bootstrap.Modal.getInstance(document.getElementById('departmentAssignModal')).hide();
            clearCache('users'); // 清除缓存，强制刷新
            loadUsers(true); // 重新加载用户列表
        } else {
            showError('部门分配失败: ' + (data.message || '未知错误'));
        }
    } catch (error) {
        console.error('保存用户部门失败:', error);
        showError('保存用户部门失败: ' + error.message);
    }
}

async function assignMBTI(userId) {
    try {
        // 获取用户当前MBTI
        const userResponse = await fetch(`${API_BASE}/users/${userId}`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const userData = await userResponse.json();
        const currentMBTI = userData.success && userData.user ? userData.user.mbit : null;
        
        // 创建MBTI选择下拉框
        const mbtiOptions = `
            <option value="">未设置</option>
            <option value="INTJ" ${currentMBTI === 'INTJ' ? 'selected' : ''}>INTJ - 建筑师</option>
            <option value="INTP" ${currentMBTI === 'INTP' ? 'selected' : ''}>INTP - 逻辑学家</option>
            <option value="ENTJ" ${currentMBTI === 'ENTJ' ? 'selected' : ''}>ENTJ - 指挥官</option>
            <option value="ENTP" ${currentMBTI === 'ENTP' ? 'selected' : ''}>ENTP - 辩论家</option>
            <option value="INFJ" ${currentMBTI === 'INFJ' ? 'selected' : ''}>INFJ - 提倡者</option>
            <option value="INFP" ${currentMBTI === 'INFP' ? 'selected' : ''}>INFP - 调停者</option>
            <option value="ENFJ" ${currentMBTI === 'ENFJ' ? 'selected' : ''}>ENFJ - 主人公</option>
            <option value="ENFP" ${currentMBTI === 'ENFP' ? 'selected' : ''}>ENFP - 竞选者</option>
            <option value="ISTJ" ${currentMBTI === 'ISTJ' ? 'selected' : ''}>ISTJ - 物流师</option>
            <option value="ISFJ" ${currentMBTI === 'ISFJ' ? 'selected' : ''}>ISFJ - 守卫者</option>
            <option value="ESTJ" ${currentMBTI === 'ESTJ' ? 'selected' : ''}>ESTJ - 总经理</option>
            <option value="ESFJ" ${currentMBTI === 'ESFJ' ? 'selected' : ''}>ESFJ - 执政官</option>
            <option value="ISTP" ${currentMBTI === 'ISTP' ? 'selected' : ''}>ISTP - 鉴赏家</option>
            <option value="ISFP" ${currentMBTI === 'ISFP' ? 'selected' : ''}>ISFP - 探险家</option>
            <option value="ESTP" ${currentMBTI === 'ESTP' ? 'selected' : ''}>ESTP - 企业家</option>
            <option value="ESFP" ${currentMBTI === 'ESFP' ? 'selected' : ''}>ESFP - 表演者</option>
        `;
        
        const modalHtml = `
            <div class="modal fade" id="mbitAssignModal" tabindex="-1">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title">设置MBTI</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-3">
                                <label class="form-label">选择MBTI类型</label>
                                <select class="form-select" id="mbitSelect">
                                    ${mbtiOptions}
                                </select>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">取消</button>
                            <button type="button" class="btn btn-warning" onclick="saveUserMBTI(${userId})">保存</button>
                        </div>
                    </div>
                </div>
            </div>
        `;
        
        // 移除旧的模态框
        const oldModal = document.getElementById('mbitAssignModal');
        if (oldModal) {
            oldModal.remove();
        }
        
        // 添加新的模态框
        document.body.insertAdjacentHTML('beforeend', modalHtml);
        
        // 显示模态框
        const modal = new bootstrap.Modal(document.getElementById('mbitAssignModal'));
        modal.show();
        
    } catch (error) {
        console.error('设置MBTI失败:', error);
        showError('设置MBTI失败: ' + error.message);
    }
}

async function saveUserMBTI(userId) {
    try {
        const mbitSelect = document.getElementById('mbitSelect');
        const mbitValue = mbitSelect.value;
        // 如果选择的是"未设置"（空字符串），发送 null；否则发送选中的值
        const mbit = mbitValue === '' ? null : mbitValue;
        
        // 如果选择的是"未设置"，需要特殊处理（因为字段可能不允许 NULL）
        // 这里先尝试发送 null，如果失败，后端会跳过更新
        const response = await fetch(`${API_BASE}/users/${userId}`, {
            method: 'PUT',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ mbit: mbit })
        });
        
        // 检查响应状态
        if (!response.ok) {
            const errorText = await response.text();
            console.error('服务器错误响应:', errorText);
            throw new Error(`HTTP ${response.status}: ${errorText.substring(0, 100)}`);
        }
        
        const data = await response.json();
        
        if (data.success) {
            showSuccess('MBTI设置成功');
            bootstrap.Modal.getInstance(document.getElementById('mbitAssignModal')).hide();
            clearCache('users'); // 清除缓存，强制刷新
            loadUsers(true); // 重新加载用户列表
        } else {
            showError('MBTI设置失败: ' + (data.message || '未知错误'));
        }
    } catch (error) {
        console.error('保存用户MBTI失败:', error);
        showError('保存用户MBTI失败: ' + error.message);
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
            clearCache('permissions'); // 清除缓存，强制刷新
            loadPermissions(true);
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

// 任务管理相关函数
let currentEditingTaskId = null;

// 显示任务模态框
async function showTaskModal(taskId = null) {
    const modal = new bootstrap.Modal(document.getElementById('taskModal'));
    const title = document.getElementById('taskModalTitle');
    const form = document.getElementById('taskForm');
    const progressContainer = document.getElementById('taskProgressContainer');
    
    // 先加载用户列表（必须在加载任务数据之前，以便正确设置负责人）
    await loadUserOptions();
    
    if (taskId) {
        title.textContent = '编辑任务';
        currentEditingTaskId = taskId;
        progressContainer.style.display = 'block';
        await loadTaskData(taskId);
    } else {
        title.textContent = '新建任务';
        currentEditingTaskId = null;
        form.reset();
        progressContainer.style.display = 'none';
        document.getElementById('taskProgress').value = 0;
        document.getElementById('progressValue').textContent = '0%';
    }
    
    modal.show();
}

// 加载任务数据用于编辑
async function loadTaskData(taskId) {
    try {
        const response = await fetch(`${API_BASE}/tasks`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success && data.tasks) {
            const task = data.tasks.find(t => t.id === taskId);
            if (task) {
                document.getElementById('taskName').value = task.name || '';
                document.getElementById('taskDescription').value = task.description || '';
                document.getElementById('taskPriority').value = task.priority || 'low';
                document.getElementById('taskStatus').value = task.status || 'pending';
                
                // 获取负责人ID（支持多种字段格式）
                const assigneeId = task.assignee_id || (task.assignee && task.assignee.id) || '';
                document.getElementById('taskAssignee').value = assigneeId;
                
                document.getElementById('taskProgress').value = task.progress || 0;
                document.getElementById('progressValue').textContent = (task.progress || 0) + '%';
                
                // 格式化截止时间
                if (task.due_time) {
                    const dueDate = new Date(task.due_time);
                    const year = dueDate.getFullYear();
                    const month = String(dueDate.getMonth() + 1).padStart(2, '0');
                    const day = String(dueDate.getDate()).padStart(2, '0');
                    const hours = String(dueDate.getHours()).padStart(2, '0');
                    const minutes = String(dueDate.getMinutes()).padStart(2, '0');
                    document.getElementById('taskDueTime').value = `${year}-${month}-${day}T${hours}:${minutes}`;
                } else {
                    document.getElementById('taskDueTime').value = '';
                }
            }
        }
    } catch (error) {
        console.error('加载任务数据失败:', error);
        showError('加载任务数据失败');
    }
}

// 加载用户选项
async function loadUserOptions() {
    try {
        const response = await fetch(`${API_BASE}/admin/users`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        const select = document.getElementById('taskAssignee');
        
        if (data.success && data.users) {
            // 保留"未分配"选项
            select.innerHTML = '<option value="">未分配</option>';
            
            data.users.forEach(user => {
                const option = document.createElement('option');
                option.value = user.id;
                option.textContent = `${user.real_name || user.username} (${user.username})`;
                select.appendChild(option);
            });
        }
    } catch (error) {
        console.error('加载用户列表失败:', error);
    }
}

// 保存任务
async function saveTask() {
    const formData = {
        name: document.getElementById('taskName').value.trim(),
        description: document.getElementById('taskDescription').value.trim(),
        priority: document.getElementById('taskPriority').value,
        status: document.getElementById('taskStatus').value,
        assigneeId: document.getElementById('taskAssignee').value || null
    };
    
    // 处理截止时间
    const dueTimeInput = document.getElementById('taskDueTime').value;
    if (dueTimeInput) {
        formData.dueTime = new Date(dueTimeInput).toISOString();
    }
    
    if (!formData.name) {
        showError('任务名称不能为空');
        return;
    }
    
    try {
        let response;
        let successMessage;
        
        if (currentEditingTaskId) {
            // 编辑任务
            formData.progress = parseInt(document.getElementById('taskProgress').value);
            
            response = await fetch(`${API_BASE}/tasks/${currentEditingTaskId}`, {
                method: 'PUT',
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });
            successMessage = '任务更新成功';
        } else {
            // 创建任务
            response = await fetch(`${API_BASE}/tasks`, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${authToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });
            successMessage = '任务创建成功';
        }
        
        const data = await response.json();
        
        if (data.success) {
            showSuccess(successMessage);
            bootstrap.Modal.getInstance(document.getElementById('taskModal')).hide();
            currentEditingTaskId = null;
            clearCache('tasks'); // 清除缓存，强制刷新
            loadTasks(true);
        } else {
            showError((currentEditingTaskId ? '更新' : '创建') + '任务失败: ' + data.message);
        }
    } catch (error) {
        console.error('保存任务失败:', error);
        showError('保存任务失败: ' + error.message);
    }
}

// 编辑任务
function editTask(taskId) {
    showTaskModal(taskId);
}

// 删除任务
async function deleteTask(taskId) {
    if (!confirm('⚠️ 警告：确定要删除这个任务吗？\n\n此操作不可撤销！')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/tasks/${taskId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        
        if (data.success) {
            showSuccess('任务删除成功');
            clearCache('tasks'); // 清除缓存，强制刷新
            loadTasks(true);
        } else {
            showError('删除任务失败: ' + data.message);
        }
    } catch (error) {
        console.error('删除任务失败:', error);
        showError('删除任务失败: ' + error.message);
    }
}

// 公司十大事项管理
let currentEditingTopItemId = null;
let currentTopItems = [];

async function loadTopItems(forceRefresh = false) {
    try {
        const topItemsCacheTtl = dataCache.topItems.ttl;
        if (!forceRefresh && isCacheValid('topItems')) {
            currentTopItems = dataCache.topItems.data || [];
            displayTopItems(currentTopItems);
            return;
        }

        const response = await fetch(`${API_BASE}/top-items`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });

        const data = await response.json();

        if (data.success) {
            currentTopItems = data.items || [];
            dataCache.topItems = { data: currentTopItems, timestamp: Date.now(), ttl: topItemsCacheTtl };
            displayTopItems(currentTopItems);
        } else {
            showError('加载公司十大事项失败: ' + data.message);
        }
    } catch (error) {
        console.error('加载公司十大事项失败:', error);
        showError('加载公司十大事项失败: ' + error.message);
    }
}

function displayTopItems(items) {
    const tbody = document.getElementById('top-items-table');
    if (!tbody) return;

    if (!items || items.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" class="text-center">暂无事项</td></tr>';
        return;
    }

    tbody.innerHTML = '';
    items.forEach(item => {
        const row = document.createElement('tr');
        const creatorName = item.creator?.realName || item.creator?.username || (item.creator?.id ? ('用户' + item.creator.id) : '-');
        const contentPreview = item.content ? (item.content.length > 80 ? item.content.substring(0, 80) + '...' : item.content) : '暂无内容';
        row.innerHTML = `
            <td>${item.orderIndex}</td>
            <td>
                <div class="fw-semibold">${item.title}</div>
                <small class="text-muted d-block">${contentPreview}</small>
            </td>
            <td>${getTopItemStatusBadge(item.status)}</td>
            <td>${creatorName}</td>
            <td>${item.createdAt ? formatDate(item.createdAt) : '-'}</td>
            <td>
                <button class="btn btn-sm btn-outline-primary me-1" onclick="editTopItem(${item.id})" title="编辑事项">
                    <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" onclick="deleteTopItem(${item.id})" title="删除事项">
                    <i class="bi bi-trash"></i>
                </button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

function getTopItemStatusBadge(status) {
    const finalStatus = typeof status === 'string' ? parseInt(status, 10) : status;
    if (finalStatus === 1) {
        return '<span class="badge bg-success">显示</span>';
    }
    return '<span class="badge bg-secondary">隐藏</span>';
}

function showTopItemModal(itemId = null) {
    const modalElement = document.getElementById('topItemModal');
    const modal = new bootstrap.Modal(modalElement);
    const titleEl = document.getElementById('topItemModalTitle');
    const form = document.getElementById('topItemForm');

    if (!form) return;

    if (itemId) {
        titleEl.textContent = '编辑事项';
        currentEditingTopItemId = itemId;
        const target = currentTopItems.find(item => item.id === itemId);
        if (target) {
            document.getElementById('topItemTitle').value = target.title || '';
            document.getElementById('topItemContent').value = target.content || '';
            document.getElementById('topItemOrder').value = target.orderIndex ?? '';
            document.getElementById('topItemStatus').value = target.status?.toString() || '1';
        }
    } else {
        titleEl.textContent = '新建事项';
        currentEditingTopItemId = null;
        form.reset();
        document.getElementById('topItemStatus').value = '1';
        document.getElementById('topItemOrder').value = '';
    }

    modal.show();
}

async function saveTopItem() {
    const title = document.getElementById('topItemTitle').value.trim();
    const content = document.getElementById('topItemContent').value.trim();
    const orderIndexValue = document.getElementById('topItemOrder').value;
    const statusValue = document.getElementById('topItemStatus').value;

    if (!title) {
        showError('事项标题不能为空');
        return;
    }

    if (orderIndexValue === '') {
        showError('排序序号不能为空');
        return;
    }

    if (statusValue === '') {
        showError('请选择状态');
        return;
    }

    const payload = {
        title,
        content: content || null,
        orderIndex: parseInt(orderIndexValue, 10),
        status: parseInt(statusValue, 10)
    };

    try {
        const url = currentEditingTopItemId ? `${API_BASE}/top-items/${currentEditingTopItemId}` : `${API_BASE}/top-items`;
        const method = currentEditingTopItemId ? 'PUT' : 'POST';

        const response = await fetch(url, {
            method,
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(payload)
        });

        const data = await response.json();

        if (data.success) {
            showSuccess(currentEditingTopItemId ? '事项更新成功' : '事项创建成功');
            bootstrap.Modal.getInstance(document.getElementById('topItemModal')).hide();
            currentEditingTopItemId = null;
            clearCache('topItems');
            loadTopItems(true);
        } else {
            showError('保存事项失败: ' + data.message);
        }
    } catch (error) {
        console.error('保存事项失败:', error);
        showError('保存事项失败: ' + error.message);
    }
}

function editTopItem(itemId) {
    showTopItemModal(itemId);
}

async function deleteTopItem(itemId) {
    if (!confirm('⚠️ 警告：确定要删除这个事项吗？\n\n此操作不可撤销！')) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE}/top-items/${itemId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });

        const data = await response.json();
        if (data.success) {
            showSuccess('事项删除成功');
            clearCache('topItems');
            loadTopItems(true);
        } else {
            showError('删除事项失败: ' + data.message);
        }
    } catch (error) {
        console.error('删除事项失败:', error);
        showError('删除事项失败: ' + error.message);
    }
}

// 查看日志详情
async function viewLogDetail(logId) {
    try {
        const response = await fetch(`${API_BASE}/logs/${logId}`, {
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        // 检查响应状态
        if (!response.ok) {
            const contentType = response.headers.get('content-type');
            if (contentType && contentType.includes('application/json')) {
                const errorData = await response.json();
                throw new Error(errorData.message || `HTTP ${response.status}: ${response.statusText}`);
            } else {
                const text = await response.text();
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
        }
        
        // 检查内容类型
        const contentType = response.headers.get('content-type');
        if (!contentType || !contentType.includes('application/json')) {
            const text = await response.text();
            console.error('响应不是JSON格式:', text.substring(0, 200));
            throw new Error('服务器返回了非JSON格式的响应');
        }
        
        const data = await response.json();
        
        if (data.success && data.log) {
            const log = data.log;
            const modal = new bootstrap.Modal(document.getElementById('logDetailModal'));
            
            // 填充日志详情
            document.getElementById('logDetailTitle').textContent = log.title || '-';
            document.getElementById('logDetailType').textContent = getLogTypeText(log.logType);
            document.getElementById('logDetailPriority').innerHTML = `<span class="badge bg-${getPriorityColor(log.priority)}">${getPriorityText(log.priority)}</span>`;
            document.getElementById('logDetailStatus').textContent = getLogStatusText(log.logStatus);
            document.getElementById('logDetailContent').textContent = log.content || '-';
            document.getElementById('logDetailTimeFrom').textContent = log.timeFrom ? formatDate(log.timeFrom) : '-';
            document.getElementById('logDetailTimeTo').textContent = log.timeTo ? formatDate(log.timeTo) : '-';
            document.getElementById('logDetailTotalHours').textContent = log.totalHours ? `${log.totalHours} 小时` : '-';
            document.getElementById('logDetailTimeTag').textContent = log.timeTag || '-';
            document.getElementById('logDetailAuthor').textContent = log.realName || log.username || `用户${log.userId}`;
            document.getElementById('logDetailTask').textContent = log.taskId ? `任务 ${log.taskId}` : '-';
            document.getElementById('logDetailProgress').textContent = log.progress !== null && log.progress !== undefined ? `${log.progress}%` : '-';
            document.getElementById('logDetailCreatedAt').textContent = log.createdAt ? formatDate(log.createdAt) : '-';
            document.getElementById('logDetailUpdatedAt').textContent = log.updatedAt ? formatDate(log.updatedAt) : '-';
            
            modal.show();
        } else {
            showError('获取日志详情失败: ' + (data.message || '未知错误'));
        }
    } catch (error) {
        console.error('查看日志详情失败:', error);
        showError('查看日志详情失败: ' + error.message);
    }
}

// 删除日志
async function deleteLog(logId) {
    if (!confirm('⚠️ 警告：确定要删除这条日志吗？\n\n此操作不可撤销！')) {
        return;
    }
    
    try {
        const response = await fetch(`${API_BASE}/logs/${logId}`, {
            method: 'DELETE',
            headers: {
                'Authorization': `Bearer ${authToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        // 检查响应状态
        if (!response.ok) {
            const contentType = response.headers.get('content-type');
            if (contentType && contentType.includes('application/json')) {
                const errorData = await response.json();
                throw new Error(errorData.message || `HTTP ${response.status}: ${response.statusText}`);
            } else {
                const text = await response.text();
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
        }
        
        // 检查内容类型
        const contentType = response.headers.get('content-type');
        if (!contentType || !contentType.includes('application/json')) {
            const text = await response.text();
            console.error('响应不是JSON格式:', text.substring(0, 200));
            throw new Error('服务器返回了非JSON格式的响应');
        }
        
        const data = await response.json();
        
        if (data.success) {
            showSuccess('日志删除成功');
            loadLogs(); // 重新加载日志列表
        } else {
            showError('删除日志失败: ' + (data.message || '未知错误'));
        }
    } catch (error) {
        console.error('删除日志失败:', error);
        showError('删除日志失败: ' + error.message);
    }
}

// 获取日志类型文本
function getLogTypeText(logType) {
    const typeMap = {
        'work': '工作',
        'study': '学习',
        'life': '生活',
        'other': '其他'
    };
    return typeMap[logType] || logType || '-';
}

// 获取日志状态文本
function getLogStatusText(logStatus) {
    const statusMap = {
        'pending': '待处理',
        'in_progress': '进行中',
        'completed': '已完成'
    };
    return statusMap[logStatus] || logStatus || '-';
}
