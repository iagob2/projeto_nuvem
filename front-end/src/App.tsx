import { useState, useEffect } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";

import {
  Dialog,
  DialogTrigger,
  DialogContent,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogHeader,
} from "@/components/ui/dialog";

import {
  AlertDialog,
  AlertDialogTrigger,
  AlertDialogContent,
  AlertDialogHeader,
  AlertDialogFooter,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogTitle,
  AlertDialogDescription,
} from "@/components/ui/alert-dialog";

import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableFooter,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

import { api } from "./services/api";

type Todo = {
  id: number;
  title: string;
  description: string;
  status?: string;
  created_at?: string;
};

function App() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [newTodo, setNewTodo] = useState({ title: "", description: "" });
  const [todoToDelete, setTodoToDelete] = useState<number | null>(null);
  const [todoToUpdate, setTodoToUpdate] = useState<Todo | null>(null);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [isUpdateDialogOpen, setIsUpdateDialogOpen] = useState(false);
  const [isLoadingCSV, setIsLoadingCSV] = useState(false);

  // -----------------------------
  // BUSCAR TODOS AO CARREGAR
  // -----------------------------
  useEffect(() => {
    const fetchTasks = async () => {
      try {
        // API Gateway retorna {tasks: [...], count: X, total: Y}
        const response = await api.get("/tasks");
        let tasks: Todo[] = [];
        
        if (Array.isArray(response.data)) {
          // Se retornar array direto
          tasks = response.data;
        } else if (response.data?.tasks && Array.isArray(response.data.tasks)) {
          // API Gateway retorna objeto com tasks
          tasks = response.data.tasks;
        } else if (response.data) {
          // Fallback: tentar usar o próprio data como array
          tasks = Array.isArray(response.data) ? response.data : [];
        }
        
        setTodos(tasks);
        console.log("✅ Tasks carregadas:", tasks.length, "tasks");
      } catch (error: any) {
        console.error("❌ Erro ao buscar tasks:", error);
        setTodos([]); // Fallback para array vazio
        
        // Mostrar mensagem apenas se não for erro de CORS ou conexão
        if (error.code !== 'ERR_NETWORK' && error.code !== 'ERR_CANCELED') {
          const errorMessage = error.response?.data?.error || error.response?.data?.detail || "Erro ao carregar tasks";
          console.warn("⚠️ Aviso:", errorMessage);
        } else {
          console.error("❌ Erro de rede - verifique se o API Gateway está acessível");
        }
      }
    };

    fetchTasks();
  }, []);

  // -----------------------------
  // ADICIONAR NOVO TODO
  // -----------------------------
  function addNewTodo() {
    if (!newTodo.title.trim()) {
      alert("Por favor, preencha o título da task.");
      return;
    }

    const payload = {
      title: newTodo.title,
      description: newTodo.description || "",
    };

    // Limpar campos antes de enviar
    const todoToAdd = { ...newTodo };
    setNewTodo({ title: "", description: "" });

    api.post("/tasks", payload)
      .then((response) => {
        // API Gateway retorna {message: "...", id: X, title: "...", description: "...", status: "..."}
        console.log("✅ Task criada:", response.data);
        const newTask: Todo = {
          id: response.data.id,
          title: response.data.title,
          description: response.data.description || "",
          status: response.data.status || "pending",
        };
        // Adicionar no início da lista para aparecer no topo
        setTodos((prev) => [newTask, ...prev]);
        // Fechar diálogo após sucesso
        setIsDialogOpen(false);
        console.log("✅ Task adicionada à lista local");
      })
      .catch((error) => {
        console.error("❌ Erro ao criar task:", error);
        // Restaurar campos em caso de erro
        setNewTodo(todoToAdd);
        
        let errorMessage = "Erro desconhecido";
        if (error.response?.data?.error) {
          errorMessage = error.response.data.error;
        } else if (error.response?.data?.detail) {
          errorMessage = error.response.data.detail;
        } else if (error.message) {
          errorMessage = error.message;
        } else if (error.code === 'ERR_NETWORK') {
          errorMessage = "Erro de conexão - verifique se o API Gateway está acessível";
        }
        
        alert(`Erro ao criar task: ${errorMessage}`);
      });
  }

  // -----------------------------
  // ATUALIZAR TODO
  // -----------------------------
  function updateTodo() {
    if (!todoToUpdate || !todoToUpdate.title.trim()) {
      alert("Por favor, preencha o título da task.");
      return;
    }

    const payload = {
      title: todoToUpdate.title,
      description: todoToUpdate.description || "",
    };

    api.put(`/tasks/${todoToUpdate.id}`, payload)
      .then((response) => {
        console.log("✅ Task atualizada:", response.data);
        // Atualizar na lista local
        setTodos((prev) =>
          prev.map((t) => (t.id === todoToUpdate.id ? { ...todoToUpdate, ...response.data.task } : t))
        );
        setIsUpdateDialogOpen(false);
        setTodoToUpdate(null);
      })
      .catch((error) => {
        console.error("❌ Erro ao atualizar task:", error);
        let errorMessage = "Erro desconhecido";
        if (error.response?.data?.error) {
          errorMessage = error.response.data.error;
        } else if (error.message) {
          errorMessage = error.message;
        }
        alert(`Erro ao atualizar task: ${errorMessage}`);
      });
  }

  // -----------------------------
  // DELETAR TODO
  // -----------------------------
  function deleteTodo(id: number) {
    api.delete(`/tasks/${id}`)
      .then(() => {
        console.log("✅ Task deletada com sucesso");
        setTodos((prev) => prev.filter((t) => t.id !== id));
        setTodoToDelete(null);
      })
      .catch((error) => {
        console.error("❌ Erro ao deletar task:", error);
        let errorMessage = "Erro desconhecido";
        if (error.response?.data?.error) {
          errorMessage = error.response.data.error;
        } else if (error.message) {
          errorMessage = error.message;
        }
        alert(`Erro ao deletar task: ${errorMessage}`);
      });
  }

  // -----------------------------
  // BAIXAR CSV
  // -----------------------------
  function downloadCSV() {
    setIsLoadingCSV(true);
    api.get("/save")
      .then((response) => {
        console.log("✅ CSV gerado:", response.data);
        
        // A Lambda salva no S3, mas podemos gerar um CSV local também
        // Ou redirecionar para o S3 se tiver URL
        if (response.data.csvUrl) {
          // Se a Lambda retornar uma URL do S3, podemos abrir em nova aba
          window.open(response.data.csvUrl, '_blank');
        } else {
          // Gerar CSV local a partir dos dados atuais
          const headers = ['id', 'title', 'description', 'status', 'created_at', 'updated_at'];
          const csvRows = [
            headers.join(',')
          ];
          
          todos.forEach(todo => {
            const csvRow = headers.map(header => {
              const value = todo[header as keyof Todo] || '';
              if (typeof value === 'string' && (value.includes(',') || value.includes('\n') || value.includes('"'))) {
                return `"${value.replace(/"/g, '""')}"`;
              }
              return value;
            });
            csvRows.push(csvRow.join(','));
          });
          
          const csvContent = csvRows.join('\n');
          const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
          const link = document.createElement('a');
          const url = URL.createObjectURL(blob);
          link.setAttribute('href', url);
          link.setAttribute('download', `tasks_${new Date().toISOString().split('T')[0]}.csv`);
          link.style.visibility = 'hidden';
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
        }
        
        alert(`CSV gerado com sucesso! ${response.data.recordsCount || todos.length} registro(s) exportado(s).`);
      })
      .catch((error) => {
        console.error("❌ Erro ao gerar CSV:", error);
        let errorMessage = "Erro desconhecido";
        if (error.response?.data?.error) {
          errorMessage = error.response.data.error;
        } else if (error.message) {
          errorMessage = error.message;
        }
        alert(`Erro ao gerar CSV: ${errorMessage}`);
      })
      .finally(() => {
        setIsLoadingCSV(false);
      });
  }

  return (
    <div className="p-6 max-w-3xl mx-auto space-y-6">
      <h1 className="text-3xl font-bold text-center">Gerenciador de Tasks</h1>

      {/* BOTÃO BAIXAR CSV */}
      <div className="flex justify-end">
        <Button 
          onClick={downloadCSV} 
          disabled={isLoadingCSV || todos.length === 0}
          variant="outline"
        >
          {isLoadingCSV ? "Gerando..." : "📥 Baixar CSV"}
        </Button>
      </div>

      {/* BOTÃO ADICIONAR */}
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogTrigger asChild>
          <Button className="w-full">Adicionar Task</Button>
        </DialogTrigger>

        <DialogContent>
          <DialogHeader>
            <DialogTitle>Nova Task</DialogTitle>
            <DialogDescription>Preencha os campos abaixo.</DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <Input
              placeholder="Título"
              value={newTodo.title}
              onChange={(e) =>
                setNewTodo({ ...newTodo, title: e.target.value })
              }
            />

            <Input
              placeholder="Descrição"
              value={newTodo.description}
              onChange={(e) =>
                setNewTodo({ ...newTodo, description: e.target.value })
              }
            />
          </div>

          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => {
                setNewTodo({ title: "", description: "" });
                setIsDialogOpen(false);
              }}
            >
              Cancelar
            </Button>

            <Button 
              onClick={addNewTodo} 
              disabled={!newTodo.title.trim()}
            >
              Salvar
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* TABELA DOS TODOS */}
      <Table>
        <TableCaption>Lista de tarefas criadas</TableCaption>

        <TableHeader>
          <TableRow>
            <TableHead>ID</TableHead>
            <TableHead>Título</TableHead>
            <TableHead>Descrição</TableHead>
            <TableHead className="text-right">Ações</TableHead>
          </TableRow>
        </TableHeader>

        <TableBody>
          {todos.length === 0 ? (
            <TableRow>
              <TableCell colSpan={4} className="text-center">
                Nenhuma task encontrada
              </TableCell>
            </TableRow>
          ) : (
            todos.map((todo) => (
              <TableRow key={todo.id}>
                <TableCell>{todo.id}</TableCell>
                <TableCell>{todo.title}</TableCell>
                <TableCell>{todo.description}</TableCell>

                <TableCell className="text-right space-x-2">
                  {/* ATUALIZAR */}
                  <Dialog open={isUpdateDialogOpen && todoToUpdate?.id === todo.id} onOpenChange={(open) => {
                    setIsUpdateDialogOpen(open);
                    if (!open) setTodoToUpdate(null);
                  }}>
                    <DialogTrigger asChild>
                      <Button 
                        variant="secondary"
                        onClick={() => {
                          setTodoToUpdate(todo);
                          setIsUpdateDialogOpen(true);
                        }}
                      >
                        Atualizar
                      </Button>
                    </DialogTrigger>

                    <DialogContent>
                      <DialogHeader>
                        <DialogTitle>Atualizar Task</DialogTitle>
                        <DialogDescription>Edite os campos abaixo.</DialogDescription>
                      </DialogHeader>

                      <div className="space-y-4">
                        <Input
                          placeholder="Título"
                          value={todoToUpdate?.title || ""}
                          onChange={(e) =>
                            setTodoToUpdate(todoToUpdate ? { ...todoToUpdate, title: e.target.value } : null)
                          }
                        />

                        <Input
                          placeholder="Descrição"
                          value={todoToUpdate?.description || ""}
                          onChange={(e) =>
                            setTodoToUpdate(todoToUpdate ? { ...todoToUpdate, description: e.target.value } : null)
                          }
                        />
                      </div>

                      <DialogFooter>
                        <Button 
                          variant="outline" 
                          onClick={() => {
                            setTodoToUpdate(null);
                            setIsUpdateDialogOpen(false);
                          }}
                        >
                          Cancelar
                        </Button>

                        <Button 
                          onClick={updateTodo} 
                          disabled={!todoToUpdate?.title.trim()}
                        >
                          Salvar
                        </Button>
                      </DialogFooter>
                    </DialogContent>
                  </Dialog>

                  {/* DELETAR */}
                  <AlertDialog>
                    <AlertDialogTrigger asChild>
                      <Button
                        variant="destructive"
                        onClick={() => setTodoToDelete(todo.id)}
                      >
                        Deletar
                      </Button>
                    </AlertDialogTrigger>

                    <AlertDialogContent>
                      <AlertDialogHeader>
                        <AlertDialogTitle>Deseja deletar?</AlertDialogTitle>
                        <AlertDialogDescription>
                          Essa ação não pode ser desfeita.
                        </AlertDialogDescription>
                      </AlertDialogHeader>

                      <AlertDialogFooter>
                        <AlertDialogCancel>Cancelar</AlertDialogCancel>
                        <AlertDialogAction
                          onClick={() => {
                            if (todoToDelete !== null) {
                              deleteTodo(todoToDelete);
                            }
                          }}
                        >
                          Deletar
                        </AlertDialogAction>
                      </AlertDialogFooter>
                    </AlertDialogContent>
                  </AlertDialog>
                </TableCell>
              </TableRow>
            ))
          )}
        </TableBody>

        <TableFooter>
          <TableRow>
            <TableCell colSpan={3}>Total: {todos.length} tarefa(s)</TableCell>
          </TableRow>
        </TableFooter>
      </Table>
    </div>
  );
}

export default App;
