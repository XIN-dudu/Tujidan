# 任务权限设计方案（简化版）

## 角色层级

```
founder (创始人) = admin (管理员) > dept_head (部门负责人) > staff (普通员工)
```

**注意**: founder 和 admin 权限完全一致，拥有所有权限。

---

## 权限设计总览

| 权限 | founder/admin | dept_head | staff |
|------|---------------|-----------|-------|
| **任务创建** | ✅ 全部 | ✅ 全部 | ❌ 不可创建 |
| **任务分配** | ✅ 任意用户 | ⚠️ 仅自己创建的任务 | ❌ 不可分配 |
| **任务接收** | ✅ 任意任务 | ✅ 自己创建的任务 | ✅ 仅分配给自己的任务 |
| **任务删除** | ✅ 任意任务 | ⚠️ 仅自己创建的任务 | ❌ 不可删除 |
| **任务查看** | ✅ 全部任务 | ⚠️ 仅自己创建的任务 | ⚠️ 仅分配给自己的任务（已分配） |

---

## 1. 任务创建权限

### 规则
- **founder/admin**: 可以创建任何任务，无限制
- **dept_head**: 可以创建任务
- **staff**: ❌ **不能创建任务**

### 任务状态逻辑
- **创建但未分配**: 状态为 `pending_assignment`（待分配）
- **创建时分配或创建后分配**: 状态为 `not_started`（待处理/未开始）

### 实现逻辑
```javascript
// 检查创建权限
if (userRole === 'staff') {
  return res.status(403).json({ 
    success: false, 
    message: '普通员工不能创建任务' 
  });
}

// 创建任务时的状态处理
let taskStatus = 'pending_assignment'; // 默认待分配

if (ownerUserId && ownerUserId !== req.user.id) {
  // 如果创建时指定了负责人，则状态为待处理
  taskStatus = 'not_started';
}
```

---

## 2. 任务分配权限

### 规则
- **founder/admin**: 可以将任务分配给任何用户（任意任务）
- **dept_head**: 只能分配**自己创建**的任务
  - 不能分配其他人创建的任务
- **staff**: ❌ **不能分配任务**

### 实现逻辑
```javascript
// 检查分配权限
if (userRole === 'staff') {
  return res.status(403).json({ 
    success: false, 
    message: '普通员工不能分配任务' 
  });
}

if (userRole === 'dept_head') {
  // 只能分配自己创建的任务
  if (task.creator_id !== req.user.id) {
    return res.status(403).json({ 
      success: false, 
      message: '只能分配自己创建的任务' 
    });
  }
}

// 分配任务时，状态从 pending_assignment 变为 not_started
if (task.status === 'pending_assignment') {
  taskStatus = 'not_started';
}
```

---

## 3. 任务接收权限

### 规则
- **founder/admin**: 可以接收、操作任何任务
- **dept_head**: 可以接收**自己创建**的任务（如果分配给自己）
- **staff**: 只能接收**分配给自己的任务**（且必须是已分配状态，即 `not_started`）

### 实现逻辑
```javascript
// 接收任务时检查权限
if (userRole === 'staff') {
  // 只能接收分配给自己的任务，且必须是已分配状态
  if (task.assignee_id !== req.user.id) {
    return res.status(403).json({ 
      success: false, 
      message: '只能接收分配给自己的任务' 
    });
  }
  
  // 必须是已分配状态（not_started），不能是待分配状态（pending_assignment）
  if (task.status === 'pending_assignment') {
    return res.status(403).json({ 
      success: false, 
      message: '任务尚未分配，无法接收' 
    });
  }
}

if (userRole === 'dept_head') {
  // 只能接收自己创建的任务
  if (task.creator_id !== req.user.id) {
    return res.status(403).json({ 
      success: false, 
      message: '只能接收自己创建的任务' 
    });
  }
}
```

---

## 4. 任务删除权限

### 规则
- **founder/admin**: 可以删除任何任务
- **dept_head**: 只能删除**自己创建**的任务
- **staff**: ❌ **不能删除任务**

### 实现逻辑
```javascript
// 检查删除权限
if (userRole === 'staff') {
  return res.status(403).json({ 
    success: false, 
    message: '普通员工不能删除任务' 
  });
}

if (userRole === 'dept_head') {
  // 只能删除自己创建的任务
  if (task.creator_id !== req.user.id) {
    return res.status(403).json({ 
      success: false, 
      message: '只能删除自己创建的任务' 
    });
  }
}
```

---

## 5. 任务查看权限（最重要）

### 规则

#### **founder/admin**
- ✅ 可以查看**所有任务**，包括：
  - 所有状态的任务
  - 所有用户创建和分配的任务
  - 待分配任务（`pending_assignment`）
  - 已分配任务（`not_started`及其他状态）

#### **dept_head（部门负责人）**
- ✅ 可以查看：
  1. **自己创建的任务**（`creator_id = 当前用户ID`）
  2. 包括所有状态：`pending_assignment`、`not_started`、`in_progress`等
  3. **不能查看**其他人创建的任务

#### **staff（普通员工）**
- ✅ 可以查看：
  1. **分配给自己的任务**（`assignee_id = 当前用户ID`）
  2. **必须是已分配状态**（`status != 'pending_assignment'`）
  3. 即：状态为 `not_started`、`in_progress`、`completed` 等
  4. **不能查看**待分配任务（除非已分配给自己）
  5. **不能查看**分配给其他人的任务

### 实现逻辑（SQL查询）

```javascript
// 获取用户角色
const userRoles = await getUserRoles(req.user.id);
const isFounderOrAdmin = userRoles.includes('founder') || userRoles.includes('admin');
const isDeptHead = userRoles.includes('dept_head');
const isStaff = userRoles.includes('staff');

let sql = 'SELECT ... FROM tasks WHERE 1=1';
const params = [];

if (isFounderOrAdmin) {
  // 查看所有任务，不需要额外条件
} else if (isDeptHead) {
  // 只能查看自己创建的任务
  sql += ' AND creator_id = ?';
  params.push(req.user.id);
} else if (isStaff) {
  // 只能查看分配给自己的任务，且必须是已分配状态
  sql += ' AND assignee_id = ? AND status != ?';
  params.push(req.user.id, 'pending_assignment');
}
```

### 权限矩阵

| 任务类型 | founder/admin | dept_head | staff |
|---------|---------------|-----------|-------|
| 自己创建的任务（所有状态） | ✅ | ✅ | ❌ |
| 分配给自己的任务（已分配） | ✅ | ⚠️ 仅自己创建的 | ✅ |
| 分配给其他人的任务 | ✅ | ❌ | ❌ |
| 其他人创建的任务 | ✅ | ❌ | ❌ |
| 待分配任务（pending_assignment） | ✅ | ⚠️ 仅自己创建的 | ❌ |

---

## 6. 任务编辑/更新权限

### 规则
- **founder/admin**: 可以编辑任何任务
- **dept_head**: 可以编辑**自己创建**的任务
- **staff**: 可以编辑**分配给自己的任务**（仅限进度、状态等有限字段）

### 实现逻辑
```javascript
if (userRole === 'staff') {
  // 只能编辑分配给自己的任务
  if (task.assignee_id !== req.user.id) {
    return res.status(403).json({ 
      success: false, 
      message: '只能编辑分配给自己的任务' 
    });
  }
  // 限制可编辑字段（不能修改分配、优先级等）
}

if (userRole === 'dept_head') {
  // 只能编辑自己创建的任务
  if (task.creator_id !== req.user.id) {
    return res.status(403).json({ 
      success: false, 
      message: '只能编辑自己创建的任务' 
    });
  }
}
```

---

## 7. 任务状态流转

### 状态定义
- **`pending_assignment`（待分配）**: 任务刚创建，尚未分配
- **`not_started`（待处理/未开始）**: 任务已分配，等待接收
- **`in_progress`（进行中）**: 任务已接收，正在执行
- **`completed`（已完成）**: 任务已完成
- **`paused`（已暂停）**: 任务暂停
- **`closed`（已关闭）**: 任务已关闭
- **`cancelled`（已取消）**: 任务已取消

### 状态流转逻辑
```
创建任务（未分配） → pending_assignment
    ↓
分配任务 → not_started
    ↓
接收任务 → in_progress
    ↓
完成任务 → completed
```

### 创建任务时的状态
```javascript
// 创建任务
if (ownerUserId && ownerUserId !== req.user.id) {
  // 创建时指定了负责人 = 创建并分配
  status = 'not_started'; // 待处理
} else {
  // 创建时未指定负责人 = 仅创建
  status = 'pending_assignment'; // 待分配
}
```

### 分配任务时的状态
```javascript
// 分配任务（从待分配变为待处理）
if (task.status === 'pending_assignment') {
  // 分配后状态变为待处理
  status = 'not_started';
}
```

---

## 8. 权限检查辅助函数

### 8.1 检查用户角色
```javascript
async function getUserRoles(userId) {
  const connection = await getConn();
  const [roles] = await connection.execute(`
    SELECT r.role_name 
    FROM roles r
    JOIN user_roles ur ON r.id = ur.role_id
    WHERE ur.user_id = ?
  `, [userId]);
  await connection.end();
  return roles.map(r => r.role_name);
}

function isFounderOrAdmin(userRoles) {
  return userRoles.includes('founder') || userRoles.includes('admin');
}

function isDeptHead(userRoles) {
  return userRoles.includes('dept_head');
}

function isStaff(userRoles) {
  return userRoles.includes('staff');
}
```

---

## 9. 实施优先级

### 第一阶段（核心功能）
1. ✅ 任务查看权限（最重要）
2. ✅ 任务创建权限
3. ✅ 任务删除权限

### 第二阶段（分配管理）
4. ✅ 任务分配权限
5. ✅ 任务接收权限

### 第三阶段（细化）
6. ✅ 任务编辑权限
7. ✅ 状态流转逻辑

---

## 总结

这个权限设计遵循了**最小权限原则**和**数据隔离原则**：
- **founder/admin**: 全局管理权限（权限完全一致）
- **dept_head**: 只能管理自己创建的任务
- **staff**: 只能查看和操作分配给自己的任务（必须是已分配状态）

关键点：
1. **staff 不能创建任务**，只能被动接收
2. **dept_head 只能看到自己创建的任务**，完全隔离
3. **任务状态明确区分**：待分配（pending_assignment）vs 待处理（not_started）
4. **staff 只能看到已分配的任务**，不能看到待分配任务
